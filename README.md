
# Table of Contents

- [Table of Contents](#table-of-contents)
- [About powershell-ffmpeg](#about-ffmpeg-ps1)
  - [Requirements](#requirements)
  - [Simplified Script Flow](#simplified-script-flow)
  - [Config In Detail](#configuration)

# About ffmpeg-ps1

This repo contains a script that i've put together using powersell as the base language. The main purpose of this script is to use [FFmpeg](https://ffmpeg.org/) to encode/convert/compress video files in media folders. This allows you to standardize file sizes throughout your media library, also enforcing maximum resolutions for longer term storage.

## Requirements

- FFMPEG needs to be installed and configured to work with CLI in powershell.

  - [How to install ffmpeg](https://gist.github.com/barbietunnie/47a3de3de3274956617ce092a3bc03a1) (Github)

- Powershell - it is availble in multiple operating systems including but not limited to:
  - Windows 7, 8, 10
  - Windows Server
  - macOS
  - Debian 9

## How I use this script

I have a plex server set up where all the users in my household can stream and watch any of our stored TV shows, movies and anime. This script is set by my OS (in this case [Task Scheduler](https://learn.microsoft.com/en-us/windows/win32/taskschd/task-scheduler-start-page)) to run twice a day to scan media, and encode files if they are over a certain size/quality threshhold. By encoding needlessly large files it saves network resources when streaming the files, in addition to lessening the burdon of streaming on the server allowing for better overall streaming experience as well as allowing my home media server to run its other services with less interruption. This primarily goes after any media sources that are provided as either RAW or with low media compression.

## Simplified Script Flow

1. Powershell begins scanning all indicated directories. Each file and folder under that path is added to contents.txt
1. Powershell will begin scanning through each file individually, skipping folders, and and attempts to determine current bitrate, resolution and calculate if the file requires encoding when compared to presets. All files scanned are added to `contents.csv` with the scanned data based on configuration.
1. When `contents.csv` is generated powershell will begin going through each line. If encoding is required it will begin the encode operation by passing through information to ffmpeg.
1. When the file encode is complete, it will dispose of the source file and move the new file to the same directory with the same naming convention.

## Configuration

When it come to configuring for use you may want to modify certain options depending on your intented use. For example, I primarily use this script in the background through a scheduled task. As this is run automatically I do not need any GUI based items enabled so those would be set to false. A copy of the default configuration can be seen below.

```powershell
    # Initial Config
        Set-PSDebug -Off
        $bVerbose = $False # If `$True` verbose messages are enabled in the console while script is running.
        $bTest = $False # If `$True` Enables test mode. Test mode only scans and encodes a single source path defined in `$bTestPath`. Destination file is saved to your `$sExportedDataPath`.
        $bTestPath = $sRootPath+"\Downloads\TestFile.mkv" # Source Path to file you want to test the script on.
        $sRootPath = "D:" # This is the root file path you want power-shell to begin scanning for media if you are wanting to scan all child items of this directory. *This becomes very important if you have `$bRecursiveSearch` set to `$False`*.
        $sEncodePath = "$sRootPath\Encode\" # The folder/path where you wish to remporarely store encodes while they are being processed. *It is recommended to use a different location from any other files.*
        $sExportedDataPath = $sScriptPath # The folder/path where you want the exported files to be generated. 'Exported files' does not include encodes.
        $bRecursiveSearch = $False # This controls if you wish to scan the entire root folder specified in `$sRootPath` for content. If `$True`, all files, folders and subfolders will be subject to at least a scan attempt. If `$False`, only the folders indicated in `$sDirectoriesCSV` will be subject to a recursive scan.
        $sDirectoriesCSV = "D:\Anime\,D:\TV\,D:\Movies\" # If you want to only have power-shell scan specific folders for media, you can indicate all paths in this variable using CSV style formatting.
        $bDisableStatus = $True # Set to true if you wish to disable the calculating and displaying of status/progress bars in the script (can increase performance)
      # Limits
        $iLimitQueue = 0 #No limit = `0`. Limits the number of files that are encoded per execution. Once this number has been reached it will stop. It can be stopped early if also used in conjunction with `$iEncodeHours`.
        $iEncodeHours = 0 #No limit = `0`. Limits time in hours you allow a single script execution to run. End time will be obtained before scanning starts. It will then check that the time has not been exceeded before each encode begins.
        If ($iLimitQueue -ne 0 -or $iEncodeHours -ne 0){$bEncodeLimit = $True}Else{$bEncodeLimit = $False} # If either of the limit controllers contain values above 0, then this is marked as `$True`
    # Exported Data
      $bEncodeOnly = $True # When this is `$True`, only items identified as "needing encode" as per the `Detect Medtadata > Video Metadata > Check if encoding needed` section. If `$False` then all items will be added to the CSV regardless if encoding will take place for the file or not. *This does not change whether or not the file **will** be encoded, only if it is logged in the generated CSV file*
      $bDeleteCSV = $False # If `$False` then `contents.csv` will be deleted after the script is finished. If `$True` then `contents.csv` will **not** be deleted after the script is finished. Instead the next time it runs it will be written over.
      $bAppendLog = $True # If `$False` then when a new encoding session begins, the contents of `encode.log` are cleared. If `$True` then the contents of said text file will append until cleared manually.
      $bDeleteContents = $True # If `$False` then the `contents.txt` file generated at scanning will not be deleted after `contents.csv` is created. If `$True` then `contents.txt` will be deleted after `contents.csv` is created.
    # Encode Config
      $bRemoveBeforeScan = $True # If `$True` then  all files in `$sEncodePath` are deleted prior to initiated a scan for media
      $bEncodeAfterScan = $True # If `$False` then once the CSV is created the script skips the encoding process entirely. If `$True` then the script will encode all identified files after the CSV is generated.
```
