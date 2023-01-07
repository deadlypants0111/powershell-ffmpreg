$sScriptPath = split-path -parent $MyInvocation.MyCommand.Definition # Gets the path of the script file being executed
try{ . ./config.ps1}
catch{ . .\config.ps1}
#Functions
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
        If ($bAppendLog -eq $False) {Clear-Content -Path $sExportedDataPath\encode.log} # Clears log file at start of encode if true, otherwise appends continuously
        If ($bDisableStatus -eq $False) {
            $iSteps = (get-content $sExportedDataPath\contents.csv).length
        } # If bDisableStatus is False then updates the gui terminal with status bar
        $Istep = 0
        #Loop through contents.csv and encode each file identified
            Import-Csv $sExportedDataPath\contents.csv | ForEach-Object {
                if($bEncodeAfterScan -eq $True){
                    try{
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
                                ffmpeg -i "$($_.path)" -b $($_.T_Bits_Ps) -maxrate $($_.T_Bits_Ps) -minrate $($_.T_Bits_Ps) -ab $sff_ab -vcodec $sff_vcodec -acodec $sff_acodec -strict $sff_strict -ac $sff_ac -ar $sff_ar -s $($_.T_height) -map $sff_map -y -threads $sff_threads -v quiet -stats $outputpath
                                #ffmpeg -i "$($_.path)" -b $($_.T_Bits_Ps) -maxrate $($_.T_Bits_Ps) -minrate $($_.T_Bits_Ps) -ab 64k -vcodec libx264 -acodec aac -strict 2 -ac 2 -ar 44100 -s $($_.T_height) -map 0 -y -threads 2 -v quiet -stats $outputpath
                            #Check thar files still exist before removal
                                $sSourcePath = Test-Path $($_.path)
                                $sDestPath = Test-Path $outputpath
                                $iDestSize = (Get-Item $outputpath).Length/1MB
                                if ($sDestPath -eq $True -and $sSourcePath -eq $True -and $iDestSize -gt 1) {
                                    #Remove input file
                                        If ($bDeleteSource -eq $True){
                                            # Delete input file if set to true
                                            remove-item $($_.path)
                                            EncodeLog("Deleted source file")
                                        }
                                        Else{
                                            # Otherwise relocate it
                                            Move-Item -Path $($_.path) -Destination "$sEncodePath\old" -Force
                                            EncodeLog("Moved source file to $sEncodePath\old")
                                        }
                                        
                                    #Move new file to original folder
                                        move-item $outputpath -Destination $sInputContainer
                                    #Populate log of encoded files
                                        $iTargetBits = ($($_.T_Bits_Ps)/1000)
                                        $iOriginBits = ($($_.Bits_Ps)/1000)
                                        EncodeLog "($iStep) $sBasename encoded in $($_.T_height)p at $iTargetBits kbp/s | Originally $iOriginBits kbp/s"
                                        Write-Verbose -Message "Complete"
                                        $iStep++
                                }
                                Else{
                                    If($iDestSize -lt 1){EncodeLog("Aborting file overwrite as encode file is less than 1MB")}
                                    Elseif($sDestPath -eq $False){EncodeLog("Aborting file overwrite as destination path does not exist anymore")}
                                    Else{EncodeLog("Aborting file overwrite as encode file does not exist anymore")}
                                }
                        }
                        If ($bDisableStatus -eq $False) {Write-Progress -Activity "Encoding: $iStep/$iSteps" -Status "$sFilename" -Completed} # If bDisableStatus is False then updates the gui terminal with status bar
                        If ($bEncodeLimit -eq $True){
                            # Checks current stats against encode limits
                            If ($iLimitQueue -gt 0 -and $iStep -ge $iLimitQueue){
                                # Confirms if limit of concurrent encodes has been reached
                                $bEncodeAfterScan = $False
                                EncodeLog("Encode Limit Reached as queue has processed $iLimitQueue file(s)")
                            }
                            If ($iEncodeHours -gt 0)
                            {
                                # Confirms the script is allowed to continue running at this time
                                $DateTime = Get-Date
                                If ($DateTime -ge $EndTime){
                                    $bEncodeAfterScan = $False
                                    EncodeLog("Encode Limit Reached as queue been reached the $iEncodeHours hour limit")
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
            }
    }
# End Fnctions
#Initialize
try {
    EncodeLog("Initializing")
    $sErrorTask = "Initializing"
    Set-Location $sRootPath # set directory of root folder for monitored videos
    $EndTime = Get-Date
    $EndTime = $EndTime.AddHours($iEncodeHours)
    If ($bVerbose -eq $True) {$VerbosePreference = "Continue"} Else {$VerbosePreference = "SilentlyContinue"} # If verbose is on, shows verbose messages in console
    If ($bRemoveBeforeScan -eq $True) {Remove-Item $sEncodePath -Include *.* -Recurse} # Remove old encodes
}
catch{
    $sErrorMessage = $_
    ErrorLog
} 
# Check folders before scanning
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
# Start Scanning
    #Generate Contents
        #Generate Contents Lists and repeat based on number of directories
            try{
                EncodeLog("Scanning Files")
                $sErrorTask = "Generating Contents List"
                out-file $sExportedDataPath\contents.txt #create empty contents file
            If ($bTest -eq $True){
                $sTestPath | Add-Content $sExportedDataPath\contents.txt # If testmode active, export single path to contents.txt 
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
            $iPercent = 0
            $ffmpeg =@(
                foreach($sContentsLine in Get-Content $sExportedDataPath\contents.txt){
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
                                    $kbps = $iBitRate480
                                    $theight = "640x480"
                                }elseif ([int]$iHeight -ge 1000) {
                                    $kbps = $iBitRate1080
                                    $theight = "1920x1080"
                                }else {
                                    $kbps = $iBitRate720
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
                    catch{
                        $sErrorMessage = $_
                        ErrorLog
                    }
                }
            )
#Export CSV
    EncodeLog("Exporting File List")
    $ffmpeg | Export-Csv -Path $sExportedDataPath\contents.csv #export array to csv
    If ($bDisableStatus -eq $False) {Write-Progress -Activity $activity -Status "Ready" -Completed} # If bDisableStatus is False then updates the gui terminal with status bar         
    If ($bDeleteContents -eq $True) {remove-item $sExportedDataPath\contents.txt}
    If ($bEncodeAfterScan -eq $True) {
        EncodeLog("Begining Encode")
        BeginEncode
        EncodeLog("Encode Finished")
    } #Begin video encode if turned on in config
    If ($bDeleteCSV -eq $True) {remove-item $sExportedDataPath\contents.csv} #Remove contents csv if marked true in config