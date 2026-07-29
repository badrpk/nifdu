$ErrorActionPreference="Stop"
$CPP="C:\nifdu\src\http\nifdu_http_server80.cpp"
$BUILD="C:\nifdu\build"

Get-Process nifdu -EA SilentlyContinue | % { try{Stop-Process -Id $_.Id -Force}catch{} }
cmd /c "taskkill /F /IM nifdu.exe >NUL 2>&1" | Out-Null
Start-Sleep -Milliseconds 650

$bak="$CPP.bak_fullCmd_fix_{0}" -f (Get-Date -Format yyyyMMdd_HHmmss)
Copy-Item $CPP $bak -Force

$src=Get-Content $CPP -Raw
$src2=$src.Replace('std::string fullCmd = "cmd /c \\"" + cmd + "\\"";','std::string fullCmd = "cmd /c \"" + cmd + "\"";')
if($src2 -eq $src){
  $src2=[regex]::Replace($src,'std::string\s+fullCmd\s*=\s*"cmd\s*/c\s*\\\\"\\"\s*\+\s*cmd\s*\+\s*"\\\\"\\""\s*;','std::string fullCmd = "cmd /c \"" + cmd + "\"";',1)
}
if($src2 -eq $src){ throw "Could not find the bad fullCmd line." }

$enc=New-Object System.Text.UTF8Encoding($false)
[IO.File]::WriteAllText($CPP,$src2,$enc)

Push-Location $BUILD
cmd /c "cmake --build . --config Release" | Out-Host
Pop-Location
