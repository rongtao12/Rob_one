## Silent install the GSA. Reference doc: [The Global Secure Access client for Windows - Global Secure Access | Microsoft Learn](https://learn.microsoft.com/en-us/entra/global-secure-access/how-to-install-windows-client)
## downloand , install , and start the appliction
## Author : Rob Rong 
## Date : 2024-10-12
# Check for administrator privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Please run this script as an administrator."
    exit
}

$folderPath = "C:\Temp"

# Check if the folder exists
if (-not (Test-Path -Path $folderPath)) {
    # Create the folder if it doesn't exist
    New-Item -Path $folderPath -ItemType Directory
    Write-Host "Folder 'C:\Temp' created."
} else {
    Write-Host "Folder 'C:\Temp' already exists."
}

# Set variables
$installerUrl = "https://aka.ms/GlobalSecureAccess-windows"
$installerPath = "C:\Temp\GlobalSecureAccessInstaller.exe"

# Download using WebClient
$webClient = New-Object System.Net.WebClient
$webClient.DownloadFile($installerUrl, $installerPath)

# Install silently
# https://learn.microsoft.com/en-us/entra/global-secure-access/how-to-install-windows-client , it support '\quiet nmode'
Start-Process -FilePath $installerPath -ArgumentList '/quiet', '/norestart' -Wait
Write-Host "Folder 'Install to C:\Program Files\Global Secure Access Client successfully"

# Remove the installer
Remove-Item $installerPath

Write-Host "Start the process"
Start-Process "C:\Program Files\Global Secure Access Client\GlobalSecureAccessClientManagerService.exe"
