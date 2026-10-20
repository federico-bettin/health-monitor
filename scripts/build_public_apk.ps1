<#
  Costruisce l'APK pubblico (da mettere nelle GitHub Releases) SENZA la tua
  chiave Anthropic: usa temporaneamente constants.template.dart al posto di
  lib/core/constants.dart, poi ripristina il tuo file originale.

  Uso (da C:\salute_bettin):   .\scripts\build_public_apk.ps1
  Risultato:                   release\HealthMonitor-<versione>.apk
#>
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$constants = Join-Path $root 'lib\core\constants.dart'
$template  = Join-Path $root 'lib\core\constants.template.dart'
$backup    = Join-Path $root 'lib\core\constants.dart.mio'

if (-not (Test-Path $template)) { throw "Manca $template" }
if (Test-Path $backup) { throw "Esiste gia' $backup: un build precedente e' stato interrotto. Ripristina a mano constants.dart da quel file e riprova." }

$hadConstants = Test-Path $constants
if ($hadConstants) { Copy-Item $constants $backup }

try {
    Copy-Item $template $constants -Force
    Write-Host '>> Build con constants.template.dart (nessuna chiave dentro)...'
    flutter build apk --release
    if ($LASTEXITCODE -ne 0) { throw 'flutter build fallita' }
}
finally {
    # Ripristina SEMPRE il tuo constants.dart
    if ($hadConstants) { Move-Item $backup $constants -Force }
    elseif (Test-Path $constants) { Remove-Item $constants -Force }
    Write-Host '>> constants.dart originale ripristinato.'
}

$apk = Join-Path $root 'build\app\outputs\flutter-apk\app-release.apk'
if (-not (Test-Path $apk)) { throw "APK non trovato: $apk" }

# --- Controllo: la chiave Anthropic non deve essere nell'APK ---
Write-Host '>> Controllo che nell''APK non ci siano chiavi...'
$tmp = Join-Path $env:TEMP ('apkcheck_' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory $tmp | Out-Null
Copy-Item $apk "$tmp\a.zip"
Expand-Archive "$tmp\a.zip" "$tmp\x" -Force
$trovato = $false
$googleKey = $false
Get-ChildItem "$tmp\x" -Recurse -File | ForEach-Object {
    $t = [Text.Encoding]::GetEncoding(28591).GetString([IO.File]::ReadAllBytes($_.FullName))
    if ($t -match 'sk-ant-api') { Write-Host "  !! chiave Anthropic in $($_.FullName)" -ForegroundColor Red; $script:trovato = $true }
    if ($t -match 'AIza[0-9A-Za-z_\-]{20,}') { $script:googleKey = $true }
}
Remove-Item $tmp -Recurse -Force
if ($trovato) { throw 'STOP: nell''APK c''e'' una chiave Anthropic. NON pubblicarlo.' }
Write-Host '   OK: nessuna chiave Anthropic.' -ForegroundColor Green
if ($googleKey) {
    Write-Host '   Nota: l''APK contiene la chiave Google (google-services.json). E'' normale, ma limitala in Google Cloud Console al package com.bettin.salute_bettin + SHA-1.' -ForegroundColor Yellow
}

# --- Copia con nome e versione ---
$ver = (Select-String -Path (Join-Path $root 'pubspec.yaml') -Pattern '^version:\s*(\S+)').Matches[0].Groups[1].Value
$ver = $ver.Split('+')[0]
New-Item -ItemType Directory -Force (Join-Path $root 'release') | Out-Null
$out = Join-Path $root "release\HealthMonitor-$ver.apk"
Copy-Item $apk $out -Force
Write-Host ">> Pronto: $out" -ForegroundColor Green
