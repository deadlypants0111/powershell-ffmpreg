$sScriptPath = split-path -parent $MyInvocation.MyCommand.Definition # Gets the path of the script file being executed
#region config
# Initial Config
    Set-PSDebug -Off # Disables debugging, only shows verbose (if enabled) and running commands
    $bVerbose = $True # If `$True` verbose messages are enabled in the console while script is running.
    $bDisableStatus = $True # Set to true if you wish to disable the calculating and displaying of status/progress bars in the script (can increase performance)
    $sRootPath = "D:" # This is the root file path you want power-shell to begin scanning for media if you are wanting to scan all child items of this directory. *This becomes very important if you have `$bRecursiveSearch` set to `$False`*.
    $sEncodePath = "D:\Encode\" # The folder/path where you wish to remporarely store encodes while they are being processed. *It is recommended to use a different location from any other files.*
    $sExportedDataPath = $sScriptPath # The folder/path where you want the exported files to be generated. 'Exported files' does not include encodes.
    $bRecursiveSearch = $False # This controls if you wish to scan the entire root folder specified in `$sRootPath` for content. If `$True`, all files, folders and subfolders will be subject to at least a scan attempt. If `$False`, only the folders indicated in `$sDirectoriesCSV` will be subject to a recursive scan.
        $sDirectoriesCSV = "D:\Anime\,D:\TV\,D:\Movies\" # If you want to only have power-shell scan specific folders for media, you can indicate all paths in this variable using CSV style formatting.
    # Script Testing
    $bTestFlow = $True # If `$True` the script will follow through all normal steps without actually encoding, moving, or deleting video files
    $bTestSingleFile = $False # If `$True` Enables test mode. Test mode only scans and encodes a single source path defined in `$sTestSinglePath`. Destination file is saved to your `$sExportedDataPath`.
    $sTestSinglePath = "D:\Downloads\TestFile.mkv" # Source Path to file you want to test the script on.
    # Execution Limits
    $iLimitQueue = 0 #No limit = `0`. Limits the number of files that are encoded per execution. Once this number has been reached it will stop. It can be stopped early if also used in conjunction with `$iEncodeHours`.
    $iEncodeHours = 0 #No limit = `0`. Limits time in hours in you allow a single script execution to run. End time will be obtained before scanning starts. It will then check that the time has not been exceeded before each encode begins.
    If ($iLimitQueue -ne 0 -or $iEncodeHours -ne 0){$bEncodeLimit = $True}Else{$bEncodeLimit = $False} # If either of the limit controllers contain values above 0, then this is marked as `$True`
# Exported Data
    $bEncodeOnly = $True # When this is `$True`, only items identified as "needing encode" as per the `Detect Medtadata > Video Metadata > Check if encoding needed` section. If `$False` then all items will be added to the CSV regardless if encoding will take place for the file or not. *This does not change whether or not the file **will** be encoded, only if it is logged in the generated CSV file*
    $bDeleteCSV = $False # If `$False` then `contents.csv` will be deleted after the script is finished. If `$True` then `contents.csv` will **not** be deleted after the script is finished. Instead the next time it runs it will be written over.
    $bAppendLog = $True # If `$False` then when a new encoding session begins, the contents of `encode.log` are cleared. If `$True` then the contents of said text file will append until cleared manually.
    $bDeleteContents = $True # If `$False` then the `contents.txt` file generated at scanning will not be deleted after `contents.csv` is created. If `$True` then `contents.txt` will be deleted after `contents.csv` is created.
    $bDeleteSource = $True # If `$True` then the source video file for each encode will be deleted entirely after encode is complete. If `$False` then the source video file is moved to `$sEncodePath\old`
# Encode Settings
    $bRemoveBeforeScan = $True # If `$True` then  all files in `$sEncodePath` are deleted prior to initiated a scan for media
    $iEncodeOrder = 3
        # If `0` then script will stop running and not continue past it's current step
        # If `1` then script will log data to CSV files but not encode any files
        # If `2` then script will encode files after CSV is generated
        # If `3` then script will encode files as they are detected without adding them to a CSV file
# Video Reolution Limits
    $iResMin = 480 # Lower limit of pixel height detection
    $iResMax = 1000 # Upper limit of pixel height detection
    $sResMin = "640x480" # If pixel height is less than `$iResMin` then encode at this quality
    $sResMed = "1280x720" # If pixel height is greater than `$iResMin` but less than `$iResMax` encode at this quality
    $sResMax = "1920x1080" # If pixel height is greater than `$iResMax` encode at this quality
# Bitrate Limit
    $iBitRateSD = 1000 # bitrate in kbps for video files with a vertical pixel count < 480
    $iBitRate720 = 2000 # bitrate in kbps for video files with a verticle pixel count > 480 and a pixel count < 1000
    $iBitRate1080 = 2500 # bitrate in kbps for video files with a verticle pixel count > 1000
# ffmpeg flags in order of use
    # `-i <inputpath>` input path for source file 
    # `-b <int>` video bitrate. Source: $_.T_Bits_Ps
    # `-maxrate <int>` maximum bitrate tolerance (in bits/s). Requires bufsize to be set. (from INT_MIN to INT_MAX) (default 0). Source: $_.T_Bits_Ps
    # `-minrate <int>` minimum bitrate tolerance (in bits/s). Most useful in setting up a CBR encode. It is of little use otherwise. (from INT_MIN to INT_MAX) (default 0). Source: $_.T_Bits_Ps
    $sff_ab = '64k'# `-ab <str>` bitrate (in bits/s) (from 0 to INT_MAX) (default 128000). Source: User defined
    $sff_vcodec = 'libx264' # `-vcodec <str>` force video codec (‘copy’ to copy stream). Source: User defined
    $sff_acodec = 'aac' # `-acodec <str>` force audio codec (‘copy’ to copy stream). Source: User defined
    $sff_strict = 2 # `-strict <int>` ED.VA… how strictly to follow the standards (from INT_MIN to INT_MAX) (default 0). Source: User defined
    $sff_ac = 2 # `-ac <int>` channels set number of audio channels. Source: User defined
    $sff_ar = 44100 # `-ar <int>` rate set audio sampling rate (in Hz). Source: User defined
    # `-s <str>` size set frame size (WxH or abbreviation). Source: $_.T_height 
    $sff_map = 0 # `-map <int>` -map [-]input_file_id[:stream_specifier][,sync_file_id[:stream_s set input stream mapping. Source: User defined
    $sff_threads = 1 # `-threads <int>` (from 0 to INT_MAX) (default 1). Source: User Defined
    # `-v <string>` set logging level. Source: Built into command
    # `-stats` print progress report during encoding
    # `<outputpath>` output path of file being created. Source: $n_path
#endregion
#region functions
    Function EncodeLog($string){
        $sTimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm"
        $sLogStamp = "$sTimeStamp $string"
        write-output $sLogStamp | add-content $sExportedDataPath\encode.log
        Write-Verbose -Message $string
    }
    Function ErrorLog{
        $sTimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm"
        $sLogStamp = "$sTimeStamp | Error $sErrorTask | $sErrorMessage"
        write-output $sLogStamp | add-content $sExportedDataPath\error.log
    }
    Function AddtoCSV {
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
    Function EncodeNow($o_bits,$o_height,$t_bits,$t_height,$execute,$s_path){
        # Encodes the current file
        try{
            if ($execute -eq "TRUE") {
                If ($bDisableStatus -eq $False) {
                    $iPercent = ($iStep/$iSteps)*100
                } # If bDisableStatus is False then updates the gui terminal with status bar
                #Collect file details
                    $sFilename = Get-ChildItem $s_path
                    $sBasename = $sFilename.BaseName #to get name only
                    If ($bTestSingleFile -eq $True) {$n_path = $sExportedDataPath+$sBasename+".mkv"} Else {$n_path = $sEncodePath+$sBasename+".mkv"}
                    
                    $sInputContainer = split-path -path $s_path
                    If ($bDisableStatus -eq $False) {Write-Progress -Activity "Encoding: $iStep/$iSteps" -Status "$sFilename" -PercentComplete $iPercent} # If bDisableStatus is False then updates the gui terminal with status bar
                    EncodeLog("Working $sFilename")
                #Create new encode
                    If(!$bTestFlow){ffmpeg -i "$s_path" -b $t_bits -maxrate $t_bits -minrate $t_bits -ab $sff_ab -vcodec $sff_vcodec -acodec $sff_acodec -strict $sff_strict -ac $sff_ac -ar $sff_ar -s $t_height -map $sff_map -y -threads $sff_threads -v quiet -stats $n_path}
                #Check thar files still exist before removal
                    if(!$bTestFlow){
                        $sSourcePath = Test-Path $s_path
                        $sDestPath = Test-Path $n_path
                        $iDestSize = (Get-Item $n_path).Length/1MB 
                    }
                    if ($sDestPath -eq $True -and $sSourcePath -eq $True -and $iDestSize -gt 1 -and !$bTestFlow) {
                        #Remove input file
                            If ($bDeleteSource -eq $True){
                                # Delete input file if set to true
                                remove-item $s_path
                                EncodeLog("Deleted source file")
                            }Else{
                                # Otherwise relocate it
                                Move-Item -Path $s_path -Destination "$sEncodePath\old\$sBasename" -Force
                                EncodeLog("Moved source file to $sEncodePath\old\$sBasename")
                            }
                            
                        #Move new file to original folder
                            move-item $n_path -Destination $sInputContainer
                        #Populate log of encoded files
                            $iTargetBits = ($t_bits/1000)
                            $iOriginBits = ($o_bits/1000)
                            $global:iStepq++
                            $global:iStep++
                            EncodeLog "($global:iStepq) $sBasename encoded in $t_height p at $iTargetBits kbp/s | Originally $iOriginBits kbp/s"
                    }Elseif($bTestFlow){
                        # Flow being tested
                        $iTargetBits = ($t_bits/1000)
                        $iOriginBits = ($o_bits/1000)
                        $global:iStepq++
                        $global:iStep++
                        EncodeLog "($global:iStepq) $sBasename test 'encoded' in $t_height p at $iTargetBits kbp/s | Originally $iOriginBits kbp/s"
                    }Else{
                        If($iDestSize -lt 1){EncodeLog("Aborting file overwrite as encode file is less than 1MB")}
                        Elseif($sDestPath -eq $False){EncodeLog("Aborting file overwrite as destination path does not exist anymore")}
                        Else{EncodeLog("Aborting file overwrite as encode file does not exist anymore")}
                    }
            }
            If ($global:bDisableStatus -eq $False) {Write-Progress -Activity "Encoding: $global:iStep/$global:iSteps" -Status "$global:sFilename" -Completed} # If bDisableStatus is False then updates the gui terminal with status bar
            If ($global:bEncodeLimit -eq $True){
                # Checks current stats against encode limits
                If ($global:iLimitQueue -gt 0 -and $global:iStepq -ge $global:iLimitQueue){
                    # Confirms if limit of concurrent encodes has been reached
                    $global:iEncodeOrder = 0
                    EncodeLog("Encode Limit Reached as queue has processed $global:iLimitQueue file(s)")
                }
                If ($global:iEncodeHours -gt 0)
                {
                    # Confirms the script is allowed to continue running at this time
                    $DateTime = Get-Date
                    If ($DateTime -ge $EndTime){
                        $global:iEncodeOrder = 0
                        EncodeLog("Encode Limit Reached as queue been reached the $global:iEncodeHours hour limit")
                    }
                }
            }
        }
        catch{
            $sErrorTask = "Encoding $sBasename"
            $sErrorMessage = $_
            ErrorLog
        }
    }
    # Begins the encoding process of all items marked "Encode = TRUE" in contents.csv
    Function EncodeFromCSV {
        #Begin encoding
        If ($bDisableStatus -eq $False) {
            $global:iSteps = (get-content $sExportedDataPath\contents.csv).length
        } # If bDisableStatus is False then updates the gui terminal with status bar
        $global:iStep = 0
        #Loop through contents.csv and encode each file identified
            Import-Csv $sExportedDataPath\contents.csv | ForEach-Object {

                if($iEncodeOrder -eq 2){
                    EncodeNow $($_.Bits_Ps) $($_.height) $($_.t_bits_ps) $($_.t_height) $($_.encode) $($_.path)
                }
            }
    }
#endregion
#region initialize
try {
    $sErrorTask = "Initializing"
    If ($bAppendLog -eq $False) {Clear-Content -Path $sExportedDataPath\encode.log} # Clears log file at start of encode if true, otherwise appends continuously
    EncodeLog("Initializing")
    Set-Location $sRootPath # set directory of root folder for monitored videos
    $EndTime = Get-Date
    $EndTime = $EndTime.AddHours($iEncodeHours)
    If ($bVerbose -eq $True) {$VerbosePreference = "Continue"} Else {$VerbosePreference = "SilentlyContinue"} # If verbose is on, shows verbose messages in console
    If ($bRemoveBeforeScan -eq $True) {Remove-Item $sEncodePath -Include *.* -Recurse} # Remove old encodes
    if($iEncodeOrder -eq 0){
        EncodeLog('Script not running as $iEncodeOrder is equal to 0')
        Exit
    }
}
catch{
    $sErrorMessage = $_
    ErrorLog
} 
#endregion
#region confirm directories
    try{
        EncodeLog("Checking Folders")
        $sErrorTask = "Checking Folders"
        If ((Test-Path -Path $sRootPath -PathType Container) -eq $False) {
            $sErrorMessage = "Root Path not found, aborting script"
            Write-Verbose -Message $sErrorMessage
            ErrorLog
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
    }
    catch{
        $sErrorMessage = $_
        ErrorLog
    }
#endregion
#region scan
    #Generate Contents Lists and repeat based on number of directories
        try{
            EncodeLog("Scanning Files")
            $sErrorTask = "Generating Contents List"
            out-file $sExportedDataPath\contents.txt #create empty contents file
        If ($bTestSingleFile -eq $True){
            $sTestSinglePath | Add-Content $sExportedDataPath\contents.txt # If testmode active, export single path to contents.txt 
            #Otherwise follow default scan export
        }ElseIf ($bRecursiveSearch -eq $False){
            $sDirectoriesCSV.Split(",") | ForEach-Object {
                Get-ChildItem -Path $_ -Recurse -Include "*" | ForEach-Object {$_.FullName} | Write-Output | Add-Content $sExportedDataPath\contents.txt
            }
        }Else{Get-ChildItem -Path $sRootPath -Recurse -Include "*" | ForEach-Object {$_.FullName} | Write-Output | Add-Content $sExportedDataPath\contents.txt}
        }
        catch{
            $sErrorMessage = $_
            ErrorLog
        }
    #Detect Metadata
        #Begin scanning files
            If ($bDisableStatus -eq $False) {$activity = "Collecting Metadata from files"} # If bDisableStatus is False then updates the gui terminal with status bar
        #Start grabbing metadata based on contents
            $iSteps = (get-content $sExportedDataPath\contents.txt).length
            $iStep = 0
            $global:iStepq = 0
            $iPercent = 0
            $ffmpeg =@(
                foreach($sContentsLine in Get-Content $sExportedDataPath\contents.txt){
                    if($iEncodeOrder -ge 1){
                        try{
                            $sErrorTask = "Obtaining Metadata"
                            If ($bDisableStatus -eq $False) {Write-Progress -Activity $activity -Status "Progress:" -PercentComplete $iPercent} # If bDisableStatus is False then updates the gui terminal with status bar
                            #Check file folder and parent folder for ".skip" file to skip the encoding of these folders
                                $sFilePath = Split-Path -Path $sContentsLine
                                $sSkipPath = $sFilePath + "\.skip"
                                $sParentPath = Split-path -Parent $sContentsLine
                                $sParentSkipPath = $sParentPath + "\.skip"
                            #If skip file not found in either path then get video metadata
                                $bScanFile = $True # Reset ScanFile for each item in contents.txt
                                If ($bTestSingleFile -eq $False) {
                                    # Runs if test mode is off - Looks for a .skip file in either the source directory or parent directy. If skip file is found, do not attempt to scan/encode file
                                    If ((Test-Path -Path $sSkipPath) -or (Test-Path -Path $sParentSkipPath)) {$bScanFile = $False}
                                } 
                                If (Test-Path -Path $sContentsLine -PathType Container) {$bScanFile = $False} # If path is to folder, do not attempt to scan/encode path
                                If ($bScanFile -eq $True) {
                            #Video Metadata
                                #$iBits = ffprobe "$sContentsLine" -v error -select_streams v:0  -show_entries stream_tags=BPS -of default=noprint_wrappers=1:nokey=1 #get the video kbps via tag (very accurate)
                                $iBits = ffprobe "$sContentsLine" -v quiet -show_entries format=bit_rate -of default=noprint_wrappers=1:nokey=1 #if tag blank then get via format (less accurate)
                                $iHeight = ffprobe "$sContentsLine"  -v quiet -select_streams v:0  -show_entries stream=height -of default=noprint_wrappers=1:nokey=1 # get video width
                                # Logic for desired bitrate based on video height
                                    if ([int]$iHeight -le $iResMin) {
                                        $kbps = $iBitRateSD
                                        $theight = $sResMin
                                    }elseif ([int]$iHeight -ge $iResMax) {
                                        $kbps = $iBitRate1080
                                        $theight = $sResMax
                                    }else {
                                        $kbps = $iBitRate720
                                        $theight = $sResMed
                                    }
                            
                                # Check if encoding needed
                                    $iScaleBits = [int]$kbps*1000
                                    If($bTestSingleFile -eq $True) {$bEncode = $True} 
                                    Elseif($iBits -eq "N/A"){
                                        $bEncode = $False
                                        Write-Verbose -Message "Encoding determined not needed for path - $sContentsLine"
                                    }
                                    ElseIf ([int]$iBits -gt $iScaleBits*1.3) {$bEncode = $True} else {
                                        $bEncode = $False
                                        Write-Verbose -Message "Encoding determined not needed for path - $sContentsLine"
                                    } # Check if bitrate is greater than target kbp/s if so mark for encode
                                
                                #Verify Encode Order
                                    if($iEncodeOrder -eq 3 -and $bEncode -eq $True){
                                        Write-Verbose -Message 'Encoding now as $iEncodeOrder is set to 3'
                                        EncodeNow $iBits $iHeight $iScaleBits $theight $bEncode $sContentsLine
                                    }ElseIf ($iEncodeOrder -eq 1 -or $iEncodeOrder -eq 2) {
                                        # Add data to array
                                        If ($bTestSingleFile -eq $True) {
                                            AddtoCSV
                                            Write-Verbose -Message "Adding to CSV as bTest is True | $sContentsLine"
                                        } #Encode test path even if it doesnt need it
                                        ElseIf ($bEncodeOnly -eq $True) {
                                            #If encode only is true, only import items needing encode into csv
                                            If ($bEncode -eq $True) {
                                                AddtoCSV
                                                Write-Verbose -Message "Adding to CSV as bEncode is True | $sContentsLine"
                                            }
                                        }Else {
                                            #If encode only is false, import all items into csv
                                            AddtoCSV
                                            Write-Verbose -Message "Adding to CSV as bEncode is False | $sContentsLine"
                                        }
                                    }
                            }Else {
                                Write-Verbose -Message "Skip file exists, or path is folder. Skipping - $sContentsLine"
                            }
                            If ($bDisableStatus -eq $False) {
                                $iStep++
                                $iPercent = ($iStep/$iSteps)*100
                            } # If bDisableStatus is False then updates the gui terminal with status bar
                        }
                        catch{
                            $sErrorMessage = $_
                            ErrorLog
                        }
                    }
                    
                }
            )
#endregion
EncodeLog("Exporting File List")
If($iEncodeOrder -eq 1 -or $iEncodeOrder -eq 2){
$ffmpeg | Export-Csv -Path $sExportedDataPath\contents.csv #export array to csv
}
If ($bDisableStatus -eq $False) {Write-Progress -Activity $activity -Status "Ready" -Completed} # If bDisableStatus is False then updates the gui terminal with status bar         
If ($bDeleteContents -eq $True) {
    # Delete contents.txt if $bDeleteContents is set to True
    EncodeLog('Deleting contents.txt as $bDeleteContents is equal to True')
    remove-item $sExportedDataPath\contents.txt
}
If ($iEncodeOrder -eq 2) {
    # Begin video encode from contents.csv if turned on in config
    EncodeLog("Begining Encode")
    EncodeFromCSV
    EncodeLog("Encode Finished")
} 
If ($bDeleteCSV -eq $True) {
    # Delete contents.csv if $bDeleteCSV is set to True
    EncodeLog('Deleting contents.csv as $bDeleteCSV is equal to True')
    remove-item $sExportedDataPath\contents.csv
} 
EncodeLog("Complete")