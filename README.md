
# ffmpeg-ps1

- [About powershell-ffmpeg](#about-ffmpeg-ps1)
  - [Requirements](#requirements)
- [User Case: Media Server](#user-case-media-server)
- [Simplified Script Flow](#simplified-script-flow)
- [Config In Detail](#configuration)

## About ffmpeg-ps1

This repo contains a script that i've put together using powersell as the base language. The main purpose of this script is to use [FFmpeg](https://ffmpeg.org/) to encode/convert/compress video files in media folders. This allows you to standardize file sizes throughout your media library, also enforcing maximum resolutions for longer term storage or consistency.

### Requirements

- FFMPEG needs to be installed and configured to work with CLI in powershell.

  - [How to install ffmpeg](https://gist.github.com/barbietunnie/47a3de3de3274956617ce092a3bc03a1) (Github)

- Powershell ([How to install](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell?view=powershell-7.3)) - it is availble in multiple operating systems including but not limited to:
  - Windows 7, 8, 10
  - Windows Server
  - macOS
  - Debian 9

## User Case: Media Server

Our user has a home media server that runs on Windows PC in which all users within their household can stream and watch any of their stored anime, movies and TV shows. Over time they noticed that they are experiencing a couple of key issues.

- When saving the media to their server newer files are coming in increasingly larger file sizes and resolutions
- They are experiencing increased load trying to transocde media on the fly with their media client that is not a direct stream. Examples include:
  - Downscaling
  - Subtitles that are being burned in
  
 While looking for solutions they only want to install the bare minimum to get a working solution. Using [PowerShell](https://learn.microsoft.com/en-us/powershell/scripting/overview?view=powershell-7.3) they are able to create and run a shell intigrated script that uses [FFmpeg](https://ffmpeg.org/about.html) to convert their oversized video files to a file format and size that fits their needs. This script is run through their operating systems task automation service ([Task Scheduler](https://learn.microsoft.com/en-us/windows/win32/taskschd/task-scheduler-start-page)/[Cron Job](https://en.wikipedia.org/wiki/Cron)/other) they can have the script run atumatically on a regular basis to maintain their library.

## Simplified Script Flow

1. Powershell begins scanning all indicated directories. Each file and folder under that path is added to contents.txt
1. Powershell will begin scanning through each file individually, skipping folders, and and attempts to determine current bitrate, resolution and calculate if the file requires encoding when compared to presets. All files scanned are added to `contents.csv` with the scanned data based on configuration.
1. When `contents.csv` is generated powershell will begin going through each line. If encoding is required it will begin the encode operation by passing through information to ffmpeg.
1. When the file encode is complete, it will dispose of the source file and move the new file to the same directory with the same naming convention.

## Configuration

When it come to configuring for use you may want to modify certain options depending on your intented use. For example, I primarily use this script in the background through a scheduled task. As this is run automatically I do not need any GUI based items enabled so those would be set to false. A copy of the default configuration can be seen below.

```powershell
# Initial Config
  Set-PSDebug -Off # Disables debugging, only shows verbose (if enabled) and running commands
  $bVerbose = $True # If `$True` verbose messages are enabled in the console while script is running.
  $bTest = $False # If `$True` Enables test mode. Test mode only scans and encodes a single source path defined in `$sTestPath`. Destination file is saved to your `$sExportedDataPath`.
  $sTestPath = "D:\Downloads\TestFile.mkv" # Source Path to file you want to test the script on.
  $sRootPath = "D:" # This is the root file path you want power-shell to begin scanning for media if you are wanting to scan all child items of this directory. *This becomes very important if you have `$bRecursiveSearch` set to `$False`*.
  $sEncodePath = "D:\Encode\" # The folder/path where you wish to remporarely store encodes while they are being processed. *It is recommended to use a different location from any other files.*
  $sExportedDataPath = $sScriptPath # The folder/path where you want the exported files to be generated. 'Exported files' does not include encodes.
  $bRecursiveSearch = $False # This controls if you wish to scan the entire root folder specified in `$sRootPath` for content. If `$True`, all files, folders and subfolders will be subject to at least a scan attempt. If `$False`, only the folders indicated in `$sDirectoriesCSV` will be subject to a recursive scan.
  $sDirectoriesCSV = "D:\Anime\,D:\TV\,D:\Movies\" # If you want to only have power-shell scan specific folders for media, you can indicate all paths in this variable using CSV style formatting.
  $bDisableStatus = $True # Set to true if you wish to disable the calculating and displaying of status/progress bars in the script (can increase performance)
# Limits
  $iLimitQueue = 0 #No limit = `0`. Limits the number of files that are encoded per execution. Once this number has been reached it will stop. It can be stopped early if also used in conjunction with `$iEncodeHours`.
  $iEncodeHours = 0 #No limit = `0`. Limits time in hours in you allow a single script execution to run. End time will be obtained before scanning starts. It will then check that the time has not been exceeded before each encode begins.
  If ($iLimitQueue -ne 0 -or $iEncodeHours -ne 0){$bEncodeLimit = $True}Else{$bEncodeLimit = $False} # If either of the limit controllers contain values above 0, then this is marked as `$True`
# Exported Data
  $bEncodeOnly = $True # When this is `$True`, only items identified as "needing encode" as per the `Detect Medtadata > Video Metadata > Check if encoding needed` section. If `$False` then all items will be added to the CSV regardless if encoding will take place for the file or not. *This does not change whether or not the file **will** be encoded, only if it is logged in the generated CSV file*
  $bDeleteCSV = $False # If `$False` then `contents.csv` will be deleted after the script is finished. If `$True` then `contents.csv` will **not** be deleted after the script is finished. Instead the next time it runs it will be written over.
  $bAppendLog = $True # If `$False` then when a new encoding session begins, the contents of `encode.log` are cleared. If `$True` then the contents of said text file will append until cleared manually.
  $bDeleteContents = $True # If `$False` then the `contents.txt` file generated at scanning will not be deleted after `contents.csv` is created. If `$True` then `contents.txt` will be deleted after `contents.csv` is created.
  $bDeleteSource = $True # If `$True` then the source video file for each encode will be deleted entirely after encode is complete. If `$False` then the source video file is moved to `$sEncodePath\old`
# Encode Confige
  $bRemoveBeforeScan = $True # If `$True` then  all files in `$sEncodePath` are deleted prior to initiated a scan for media
  $iEncodeOrder = 2
    # If `0` then script will stop running and not continue past it's current step
    # If `1` then script will log data to CSV files but not encode any files
    # If `2` then script will encode files after CSV is generated
    # If `3` then script will encode files as they are detected without adding them to a CSV file
# Bitrate Configuration
  $iBitRate480 = 1000 # bitrate in kbps for video files with a vertical pixel count < 480
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
  $sff_threads = 2 # `-threads <int>` (from 0 to INT_MAX) (default 1). Source: User Defined
  # `-v <string>` set logging level. Source: Built into command
  # `-stats` print progress report during encoding
  # `<outputpath>` output path of file being created. Source: $n_path
```
