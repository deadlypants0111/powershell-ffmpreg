$sScriptPath = split-path -parent $MyInvocation.MyCommand.Definition # Gets the path of the script file being executed
#config
    # Initial Config
        Set-PSDebug -Off
        $bVerbose = $False # If `$True` verbose messages are enabled in the console while script is running.
        $bTest = $False # If `$True` Enables test mode. Test mode only scans and encodes a single source path defined in `$bTestPath`. Destination file is saved to your `$sExportedDataPath`.
        $bTestPath = $sRootPath+"\Downloads\TestFile.mkv" # Source Path to file you want to test the script on.
        $sRootPath = "D:\" # This is the root file path you want power-shell to begin scanning for media if you are wanting to scan all child items of this directory. *This becomes very important if you have `$bRecursiveSearch` set to `$False`*.
        $sEncodePath = "$sRootPath\Encode\" # The folder/path where you wish to remporarely store encodes while they are being processed. *It is recommended to use a different location from any other files.*
        $sExportedDataPath = $sScriptPath # The folder/path where you want the exported files to be generated. 'Exported files' does not include encodes.
        $bRecursiveSearch = $False # This controls if you wish to scan the entire root folder specified in `$sRootPath` for content. If `$True`, all files, folders and subfolders will be subject to at least a scan attempt. If `$False`, only the folders indicated in `$sDirectoriesCSV` will be subject to a recursive scan.
        $sDirectoriesCSV = "D:\Anime\,D:\TV\,D:\Movies\" # If you want to only have power-shell scan specific folders for media, you can indicate all paths in this variable using CSV style formatting.
        $bDisableStatus = $True # Set to true if you wish to disable the calculating and displaying of status/progress bars in the script (can increase performance)
    # Exported Data
        $bEncodeOnly = $True # When this is `$True`, only items identified as "needing encode" as per the `Detect Medtadata > Video Metadata > Check if encoding needed` section. If `$False` then all items will be added to the CSV regardless if encoding will take place for the file or not. *This does not change whether or not the file **will** be encoded, only if it is logged in the generated CSV file*
        $bDeleteCSV = $False # If `$False` then `contents.csv` will be deleted after the script is finished. If `$True` then `contents.csv` will **not** be deleted after the script is finished. Instead the next time it runs it will be written over.
        $bAppendLog = $True # If `$False` then when a new encoding session begins, the contents of `Encode_Log.txt` are cleared. If `$True` then the contents of said text file will append until cleared manually.
        $bDeleteContents = $True # If `$False` then the `contents.txt` file generated at scanning will not be deleted after `contents.csv` is created. If `$True` then `contents.txt` will be deleted after `contents.csv` is created.
    # Encode Config
        $bRemoveBeforeScan = $True # If `$True` then  all files in `$sEncodePath` are deleted prior to initiated a scan for media
        $bEncodeAfterScan = $True # If `$False` then once the CSV is created the script skips the encoding process entirely. If `$True` then the script will encode all identified files after the CSV is generated.
#Functions
    Function EncodeCSV {
        # Adds current scanned item to Encode.csv if it meets the requirements
        [pscustomobject]@{
            Bits_Ps = $iBits
            height = $iHeight
            T_Bits_Ps = $iScaleBits
            T_height = $theight
            Encode = $bEncode
            Path = $sContentsLine
        }
    }
    # Begins the encoding process of all items marked "Encode = TRUE" in contents.csv
    Function BeginEncode {
        #Begin encoding
        If ($bAppendLog -eq $False) {Clear-Content -Path $sExportedDataPath\encode_log.txt} # Clears log file at start of encode if true, otherwise appends continuously
        If ($bDisableStatus -eq $False) {
            $iSteps = (get-content $sExportedDataPath\contents.csv).length
            $iStep = 1
        } # If bDisableStatus is False then updates the gui terminal with status bar
        #Loop through contents.csv and encode each file identified
            Import-Csv $sExportedDataPath\contents.csv | ForEach-Object {
            if ($($_.encode) -eq "TRUE") {
                If ($bDisableStatus -eq $False) {
                    $iPercent = ($iStep/$iSteps)*100
                } # If bDisableStatus is False then updates the gui terminal with status bar
                #Collect file details
                    $sFilename = Get-ChildItem $($_.path)
                    $sBasename = $sFilename.BaseName #to get name only
                    If ($bTest -eq $True) {$outputpath = $sExportedDataPath+$sBasename+".mkv"} Else {$outputpath = $sEncodePath+$sBasename+".mkv"}
                    
                    $sInputContainer = split-path -path $($_.path)
                    If ($bDisableStatus -eq $False) {Write-Progress -Activity "Encoding: $iStep/$iSteps" -Status "$sFilename" -PercentComplete $iPercent} # If bDisableStatus is False then updates the gui terminal with status bar
                    Write-Verbose -Message "Working $sFilename"
                #Create new encode
                    ffmpeg -i "$($_.path)" -b $($_.T_Bits_Ps) -maxrate $($_.T_Bits_Ps) -minrate $($_.T_Bits_Ps) -ab 64k -vcodec libx264 -acodec aac -strict 2 -ac 2 -ar 44100 -s $($_.T_height) -map 0 -y -threads 2 -v quiet -stats $outputpath
                #Check thar files still exist before removal
                    $sSourcePath = Test-Path $($_.path)
                    $sDestPath = Test-Path $outputpath
                    if ($sDestPath -eq $True -and $sSourcePath -eq $True) {
                        #Remove input file
                            remove-item $($_.path)
                        #Move new file to original folder
                            move-item $outputpath -Destination $sInputContainer
                        #Populate log of encoded files
                            $sTimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm"
                            $sLogStamp = $sTimeStamp+" "+$sBasename+" encoded in "+$($_.T_height)+"p at "+($($_.T_Bits_Ps)/1000)+"kbp/s | Originally "+$($_.Bits_Ps)/1000+"kbp/s"
                            write-output $sLogStamp | add-content $sExportedDataPath\encode_log.txt
                            If ($bDisableStatus -eq $False) {$iStep++} # If bDisableStatus is False then updates the gui terminal with status bar
                            Write-Verbose -Message "Complete"
                    }
            }
            If ($bDisableStatus -eq $False) {Write-Progress -Activity "Encoding: $iStep/$iSteps" -Status "$sFilename" -Completed} # If bDisableStatus is False then updates the gui terminal with status bar
        }
    }
# End Fnctions
Set-Location $sRootPath # set directory of root folder for monitored videos
If ($bVerbose -eq $True) {$VerbosePreference = "Continue"} Else {$VerbosePreference = "SilentlyContinue"} # If verbose is on, shows verbose messages in console
If ($bRemoveBeforeScan -eq $True) {Remove-Item $sEncodePath -Include *.* -Recurse} # Remove old encodes
# Check folders before scanning
    If ((Test-Path -Path $sRootPath -PathType Container) -eq $False) {
        Write-Verbose -Message "Root Path not found, aborting script"
        Exit
    }Else{Write-Verbose -Message "Root path found"}
    If ((Test-Path -Path $sEncodePath -PathType Container) -eq $False) {
        Write-Verbose -Message "Encode Path not found, creating folder"
        New-Item -ItemType "directory" -Path $sEncodePath
        #Test path again
        If ((Test-Path -Path $sEncodePath -PathType Container) -eq $False) {
            Write-Verbose -Message "Failed to create folder, redirecting to root path"
            $sEncodePath = $sRootPath
        }
    }Else{Write-Verbose -Message "Encode path found"}
# Start Scanning
    #Generate Contents
        #Generate Contents Lists and repeat based on number of directories
        out-file $sExportedDataPath\contents.txt #create empty contents file
        If ($bTest -eq $True){
            $bTestPath | Add-Content $sExportedDataPath\contents.txt # If testmode active, export single path to contents.txt 
            #Otherwise follow default scan export
        }ElseIf ($bRecursiveSearch -eq $False){
            $sDirectoriesCSV.Split(",") | ForEach-Object {
                Get-ChildItem -Path $_ -Recurse -Include "*" | ForEach-Object {$_.FullName} | Write-Output | Add-Content $sExportedDataPath\contents.txt
            }
        }Else{Get-ChildItem -Path $sRootPath -Recurse -Include "*" | ForEach-Object {$_.FullName} | Write-Output | Add-Content $sExportedDataPath\contents.txt}
    #Detect Metadata
        #Begin scanning files
            If ($bDisableStatus -eq $False) {$activity = "Collecting Metadata from files"} # If bDisableStatus is False then updates the gui terminal with status bar
        #Start grabbing metadata based on contents
            $iSteps = (get-content $sExportedDataPath\contents.txt).length
            $iStep = 0
            $iPercent = 0
            $ffmpeg =@(
                foreach($sContentsLine in Get-Content $sExportedDataPath\contents.txt){
                    If ($bDisableStatus -eq $False) {Write-Progress -Activity $activity -Status "Progress:" -PercentComplete $iPercent} # If bDisableStatus is False then updates the gui terminal with status bar
                    #Check file folder and parent folder for ".skip" file to skip the encoding of these folders
                        $sFilePath = Split-Path -Path $sContentsLine
                        $sSkipPath = $sFilePath + "\.skip"
                        $sParentPath = Split-path -Parent $sContentsLine
                        $sParentSkipPath = $sParentPath + "\.skip"
                    #If skip file not found in either path then get video metadata
                        $bScanFile = $True # Reset ScanFile for each item in contents.txt

                        If ($bTest -eq $False) {
                            If ((Test-Path -Path $sSkipPath) -and (Test-Path -Path $sParentSkipPath)) {$bScanFile = $False}
                        } # Runs if test mode is off - Looks for a .skip file in either the source directory or parent directy. If skip file is found, do not attempt to scan/encode file
                        If (Test-Path -Path $sContentsLine -PathType Container) {$bScanFile = $False} # If path is to folder, do not attempt to scan/encode path
                        If ($bScanFile -eq $True) {
                    #Video Metadata
                        #$iBits = ffprobe "$sContentsLine" -v error -select_streams v:0  -show_entries stream_tags=BPS -of default=noprint_wrappers=1:nokey=1 #get the video kbps via tag (very accurate)
                        $iBits = ffprobe "$sContentsLine" -v quiet -show_entries format=bit_rate -of default=noprint_wrappers=1:nokey=1 #if tag blank then get via format (less accurate)
                        $iHeight = ffprobe "$sContentsLine"  -v quiet -select_streams v:0  -show_entries stream=height -of default=noprint_wrappers=1:nokey=1 # get video width
                    
                        # Logic for desired bitrate based on video height
                            if ([int]$iHeight -le 480) {
                                $kbps = 1000
                                $theight = "640x480"
                            }elseif ([int]$iHeight -ge 1000) {
                                $kbps = 2500
                                $theight = "1920x1080"
                            }else {
                                $kbps = 2000
                                $theight = "1280x720"
                            }
                    
                        # Check if encoding needed
                            $iScaleBits = [int]$kbps*1000
                            If($bTest -eq $True) {$bEncode = $True} ElseIf ([int]$iBits -gt $iScaleBits*1.3) {$bEncode = $True} else {
                                $bEncode = $False
                                Write-Verbose -Message "Encoding determined not needed for path - $sContentsLine"
                            } # Check if bitrate is greater than target kbp/s if so mark for encode
                    
                        # Add data to array
                            If ($bTest -eq $True) {
                                EncodeCSV
                                Write-Verbose -Message "Adding to CSV as bTest is True $sContentsLine"
                            } #Encode test path even if it doesnt need it
                            ElseIf ($bEncodeOnly -eq $True) {
                                #If encode only is true, only import items needing encode into csv
                                If ($bEncode -eq $True) {
                                    EncodeCSV
                                    Write-Verbose -Message "Adding to CSV as bEncode is True - $sContentsLine"
                                }
                            }Else {
                                #If encode only is false, import all items into csv
                                EncodeCSV
                                Write-Verbose -Message "Adding to CSV as bEncode is False - $sContentsLine"
                            }

                    }Else {
                        Write-Verbose -Message "Skip file exists, or path is folder. Skipping - $sContentsLine"
                    }
                    If ($bDisableStatus -eq $False) {
                        $iStep++
                        $iPercent = ($iStep/$iSteps)*100
                    } # If bDisableStatus is False then updates the gui terminal with status bar
                    
                }
            )
#Export CSV
    $ffmpeg | Export-Csv -Path $sExportedDataPath\contents.csv #export array to csv
    If ($bDisableStatus -eq $False) {Write-Progress -Activity $activity -Status "Ready" -Completed} # If bDisableStatus is False then updates the gui terminal with status bar         
    If ($bDeleteContents -eq $True) {remove-item $sExportedDataPath\contents.txt}
    If ($bEncodeAfterScan -eq $True) {BeginEncode} #Begin video encode if turned on in config
    If ($bDeleteCSV -eq $True) {remove-item $sExportedDataPath\contents.csv} #Remove contents csv if marked true in config

