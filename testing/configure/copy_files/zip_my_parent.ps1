# PowerShell Script to Zip Parent Directory and Output the Path of the Zip File
# This script will zip the parent directory of the script's location and output the path of the zip file.
# Example:
# Path to this zip script
# $zipScriptPath = "C:\path\to\zip_my_parent.ps1"
# Execute the zip script and capture the output (filename of the zip file)
# $zipFilePath = & $zipScriptPath

# Get the full path of the script's parent directory
$scriptParentDir = Split-Path -Parent $PSScriptRoot

# Get the name of the parent directory
$parentDirName = Split-Path -Leaf $scriptParentDir

# Define the destination path for the zip file (adjacent to the parent directory)
$destinationZipPath = Join-Path -Path (Split-Path -Parent $scriptParentDir) -ChildPath ("$parentDirName.zip")

# Create the zip file
Compress-Archive -Path "$scriptParentDir\*" -DestinationPath $destinationZipPath -Force

# Output the path of the created zip file
$destinationZipPath
