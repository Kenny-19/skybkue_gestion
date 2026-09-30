# =====================================================================
#  Skyblue - Script de release "tout-en-un"
#
#  Usage :
#    .\release.ps1 -Version 0.3.0
#      -> build + package + hash + genere manifest (upload manuel)
#
#    .\release.ps1 -Version 0.3.0 -Upload
#      -> tout ce qui precede + upload Supabase + purge anciennes versions
#
#    .\release.ps1 -Version 0.3.0 -Upload -Clean
#      -> ajoute un flutter clean avant le build (recommande apres crash)
#
#  Le flag -Upload necessite un fichier .secrets.local (voir template
#  .secrets.local.example) contenant SUPABASE_URL et SUPABASE_SERVICE_ROLE.
#  Ce fichier NE DOIT PAS etre commite (deja dans .gitignore).
#
#  Retention : les 3 dernieres versions de l'installeur sont conservees
#  sur Supabase (et localement dans installer/). Les plus vieilles sont
#  supprimees automatiquement apres chaque upload reussi.
# =====================================================================

param(
  [Parameter(Mandatory = $true)]
  [string]$Version,

  [string]$Notes = "Corrections et ameliorations diverses.",
  [switch]$Mandatory,
  [switch]$Clean,
  [switch]$Upload
)

$ErrorActionPreference = "Stop"

# Combien de versions on garde (local + Supabase). Les plus anciennes
# sont supprimees automatiquement.
$Retention = 3

# ---------------- Detection Flutter ------------------------------------
$FlutterExe = $null
$cmd = Get-Command flutter -ErrorAction SilentlyContinue
if ($cmd) { $FlutterExe = $cmd.Source }
if (-not $FlutterExe) {
  $candidates = @(
    "$env:USERPROFILE\develop\flutter\bin\flutter.bat",
    "$env:USERPROFILE\flutter\bin\flutter.bat",
    "C:\src\flutter\bin\flutter.bat",
    "C:\flutter\bin\flutter.bat",
    "C:\tools\flutter\bin\flutter.bat"
  )
  foreach ($c in $candidates) {
    if (Test-Path -LiteralPath $c) { $FlutterExe = $c; break }
  }
}
if (-not $FlutterExe) {
  Write-Host "[ERREUR] Flutter introuvable." -ForegroundColor Red
  exit 1
}
Write-Host "  [OK] Flutter : $FlutterExe" -ForegroundColor Green

# ---------------- Sanity checks ----------------------------------------
if ($Version -notmatch '^\d+\.\d+\.\d+$') {
  Write-Host "[ERREUR] Version invalide '$Version'. Attendu : MAJOR.MINOR.PATCH" -ForegroundColor Red
  exit 1
}

$InstallerDir = $PSScriptRoot
$ProjectDir = Split-Path -Parent $InstallerDir
Push-Location $ProjectDir

Write-Host ""
Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host "  Release Skyblue $Version" -ForegroundColor Cyan
Write-Host "=====================================================" -ForegroundColor Cyan

# ---------------- 1. Build Flutter -------------------------------------
if ($Clean) {
  Write-Host ""
  Write-Host "[0/5] flutter clean (option -Clean)..." -ForegroundColor Yellow
  & $FlutterExe clean
}

Write-Host ""
# Cles Supabase : jamais dans le code source. Elles sont lues depuis
# installer/supabase.env (non versionne), au format KEY=VALEUR.
# Voir installer/README.md. Sans ce fichier, le build produit une app
# 100% locale (comptes de secours uniquement) : on previent, on continue.
$EnvFile = Join-Path $PSScriptRoot "supabase.env"
$SupabaseDefines = @()
if (Test-Path $EnvFile) {
  foreach ($line in Get-Content $EnvFile) {
    $trimmed = $line.Trim()
    if ($trimmed -eq "" -or $trimmed.StartsWith("#")) { continue }
    $idx = $trimmed.IndexOf("=")
    if ($idx -lt 1) { continue }
    $key = $trimmed.Substring(0, $idx).Trim()
    $val = $trimmed.Substring($idx + 1).Trim()
    if ($key -eq "SUPABASE_URL" -or $key -eq "SUPABASE_ANON_KEY") {
      $SupabaseDefines += "--dart-define=$key=$val"
    }
  }
}
# Plus de build 100 % local : une version sans cloud envoyee aux postes
# les couperait des comptes et de la synchro. On s'arrete net.
if ($SupabaseDefines.Count -lt 2) {
  Write-Host "[ERREUR] Cles Supabase absentes de installer\supabase.env." -ForegroundColor Red
  Write-Host "         Renseigne SUPABASE_URL et SUPABASE_ANON_KEY, puis relance." -ForegroundColor Yellow
  Pop-Location; exit 1
} else {
  Write-Host "  [OK] Cles Supabase chargees depuis supabase.env" -ForegroundColor Green
}

Write-Host "[1/5] Build Flutter Windows (release)..." -ForegroundColor Yellow
& $FlutterExe build windows --release --dart-define=APP_VERSION=$Version @SupabaseDefines
if ($LASTEXITCODE -ne 0) {
  Write-Host "[ERREUR] flutter build a echoue." -ForegroundColor Red
  Pop-Location; exit 1
}
$ReleaseBuild = Join-Path $ProjectDir "build\windows\x64\runner\Release"
if (-not (Test-Path $ReleaseBuild)) {
  Write-Host "[ERREUR] Dossier Release introuvable." -ForegroundColor Red
  Pop-Location; exit 1
}
Write-Host "  [OK] Build compile" -ForegroundColor Green

# ---------------- 2. NSIS ----------------------------------------------
Write-Host ""
Write-Host "[2/5] Compile l'installeur NSIS..." -ForegroundColor Yellow
Push-Location $InstallerDir
if (-not (Get-Command makensis -ErrorAction SilentlyContinue)) {
  Write-Host "[ERREUR] makensis introuvable dans le PATH." -ForegroundColor Red
  Pop-Location; Pop-Location; exit 1
}
& makensis /DAPP_VERSION=$Version skyblue.nsi
if ($LASTEXITCODE -ne 0) {
  Write-Host "[ERREUR] NSIS a echoue." -ForegroundColor Red
  Pop-Location; Pop-Location; exit 1
}
$InstallerExe = Join-Path $InstallerDir "skyblue-setup-$Version.exe"
$installerSize = (Get-Item $InstallerExe).Length
Write-Host ("  [OK] {0} ({1:N1} Mo)" -f $InstallerExe, ($installerSize / 1MB)) -ForegroundColor Green

# ---------------- 3. Hash + manifest -----------------------------------
Write-Host ""
Write-Host "[3/5] SHA-256 + manifest..." -ForegroundColor Yellow
$hash = (Get-FileHash -Algorithm SHA256 $InstallerExe).Hash.ToLower()

$supabaseBase = "https://wdwhfgawuozhkeflgcvs.supabase.co/storage/v1/object/public/releases"
$downloadUrl = "$supabaseBase/skyblue-setup-$Version.exe"
$manifest = [ordered]@{
  version                = $Version
  release_date           = (Get-Date -Format "yyyy-MM-dd")
  download_url           = $downloadUrl
  sha256                 = $hash
  size_bytes             = $installerSize
  notes                  = $Notes
  mandatory              = [bool]$Mandatory
  min_version_to_upgrade = $null
}
$manifestPath = Join-Path $InstallerDir "manifest.json"
# ATTENTION : ecriture SANS BOM, volontairement.
#
# `Set-Content -Encoding UTF8` en PowerShell 5.1 prefixe le fichier de
# trois octets (EF BB BF). Le `jsonDecode` de Dart leve dessus, donc
# l'application n'arrivait plus a lire le manifeste -- et la banniere de
# mise a jour ne se declenchait JAMAIS. En silence : le controle echouait
# sans rien afficher, et les postes sont restes bloques en 0.0.19 pendant
# des jours sans qu'on comprenne pourquoi.
$utf8SansBom = New-Object System.Text.UTF8Encoding $false
$manifestJson = $manifest | ConvertTo-Json -Depth 3
[System.IO.File]::WriteAllText($manifestPath, $manifestJson, $utf8SansBom)
Write-Host "  [OK] SHA-256 : $hash" -ForegroundColor Green
Write-Host "  [OK] $manifestPath" -ForegroundColor Green

Pop-Location  # sort de installer/

# ---------------- 4. Upload Supabase (optionnel) -----------------------
if ($Upload) {
  Write-Host ""
  Write-Host "[4/5] Upload vers Supabase..." -ForegroundColor Yellow

  $secretsFile = Join-Path $InstallerDir ".secrets.local"
  if (-not (Test-Path $secretsFile)) {
    Write-Host "[ERREUR] .secrets.local introuvable dans installer/." -ForegroundColor Red
    Write-Host "         Cree-le depuis .secrets.local.example et remplis les valeurs." -ForegroundColor Yellow
    Pop-Location; exit 1
  }

  # Parse .secrets.local (format KEY=value)
  $secrets = @{}
  Get-Content $secretsFile | ForEach-Object {
    if ($_ -match '^\s*([^#=][^=]*)=(.*)$') {
      $k = $Matches[1].Trim()
      $v = $Matches[2].Trim() -replace '^"|"$', ''
      $secrets[$k] = $v
    }
  }
  $sbUrl = $secrets['SUPABASE_URL']
  $srKey = $secrets['SUPABASE_SERVICE_ROLE']
  if (-not $sbUrl -or -not $srKey) {
    Write-Host "[ERREUR] SUPABASE_URL ou SUPABASE_SERVICE_ROLE manquant dans .secrets.local" -ForegroundColor Red
    Pop-Location; exit 1
  }

  $bucket = 'releases'
  $authHeaders = @{
    'Authorization' = "Bearer $srKey"
    'apikey' = $srKey
  }

  # -- Upload .exe (upsert)
  $exeName = Split-Path -Leaf $InstallerExe
  Write-Host "  Upload $exeName ..." -ForegroundColor Yellow
  try {
    $exeBytes = [System.IO.File]::ReadAllBytes($InstallerExe)
    $uploadHeaders = $authHeaders + @{
      'Content-Type' = 'application/octet-stream'
      'x-upsert' = 'true'
    }
    Invoke-RestMethod `
      -Uri "$sbUrl/storage/v1/object/$bucket/$exeName" `
      -Method Post `
      -Headers $uploadHeaders `
      -Body $exeBytes | Out-Null
    Write-Host "    [OK] $exeName ($([math]::Round($installerSize / 1MB, 1)) Mo)" -ForegroundColor Green
  } catch {
    Write-Host "[ERREUR] Upload .exe echoue : $_" -ForegroundColor Red
    Pop-Location; exit 1
  }

  # -- Upload manifest.json (upsert)
  Write-Host "  Upload manifest.json ..." -ForegroundColor Yellow
  try {
    $manifestBytes = [System.IO.File]::ReadAllBytes($manifestPath)
    $manifestHeaders = $authHeaders + @{
      'Content-Type' = 'application/json'
      'x-upsert' = 'true'
    }
    Invoke-RestMethod `
      -Uri "$sbUrl/storage/v1/object/$bucket/manifest.json" `
      -Method Post `
      -Headers $manifestHeaders `
      -Body $manifestBytes | Out-Null
    Write-Host "    [OK] manifest.json" -ForegroundColor Green
  } catch {
    Write-Host "[ERREUR] Upload manifest echoue : $_" -ForegroundColor Red
    Pop-Location; exit 1
  }

  # -- Purge : garde les $Retention versions les plus recentes
  Write-Host ""
  Write-Host "[5/5] Purge des anciennes versions (garde $Retention)..." -ForegroundColor Yellow
  try {
    $listBody = @{
      prefix = ''
      limit = 100
      sortBy = @{ column = 'name'; order = 'desc' }
    } | ConvertTo-Json
    $listHeaders = $authHeaders + @{ 'Content-Type' = 'application/json' }
    $files = Invoke-RestMethod `
      -Uri "$sbUrl/storage/v1/object/list/$bucket" `
      -Method Post `
      -Headers $listHeaders `
      -Body $listBody

    # Filtre uniquement les skyblue-setup-X.Y.Z.exe et trie par semver desc
    $installers = @($files | Where-Object { $_.name -match '^skyblue-setup-\d+\.\d+\.\d+\.exe$' })
    $installers = $installers | Sort-Object -Property @{Expression = {
      if ($_.name -match 'skyblue-setup-(\d+)\.(\d+)\.(\d+)\.exe') {
        [System.Version]::new([int]$Matches[1], [int]$Matches[2], [int]$Matches[3])
      } else { [System.Version]'0.0.0' }
    }} -Descending

    if ($installers.Count -gt $Retention) {
      $toDelete = $installers[$Retention..($installers.Count - 1)]
      $deleteNames = $toDelete | ForEach-Object { $_.name }
      $deleteBody = @{ prefixes = $deleteNames } | ConvertTo-Json
      Invoke-RestMethod `
        -Uri "$sbUrl/storage/v1/object/$bucket" `
        -Method Delete `
        -Headers $listHeaders `
        -Body $deleteBody | Out-Null
      Write-Host "  [OK] Supprime sur Supabase : $($deleteNames -join ', ')" -ForegroundColor Green
    } else {
      Write-Host "  [OK] Rien a purger cote Supabase (< $Retention versions)" -ForegroundColor Green
    }
  } catch {
    Write-Host "[WARN] Purge Supabase echouee (upload OK quand meme) : $_" -ForegroundColor Yellow
  }

  # -- Purge locale : meme logique dans installer/
  $localInstallers = Get-ChildItem $InstallerDir -Filter 'skyblue-setup-*.exe' |
    Where-Object { $_.Name -match '^skyblue-setup-\d+\.\d+\.\d+\.exe$' } |
    Sort-Object -Property @{Expression = {
      if ($_.Name -match 'skyblue-setup-(\d+)\.(\d+)\.(\d+)\.exe') {
        [System.Version]::new([int]$Matches[1], [int]$Matches[2], [int]$Matches[3])
      }
    }} -Descending
  if ($localInstallers.Count -gt $Retention) {
    $toDeleteLocal = $localInstallers[$Retention..($localInstallers.Count - 1)]
    foreach ($f in $toDeleteLocal) { Remove-Item $f.FullName -Force }
    Write-Host "  [OK] Supprime en local : $($toDeleteLocal.Name -join ', ')" -ForegroundColor Green
  }
}

Pop-Location  # sort du projet

# ---------------- Recap -------------------------------------------------
Write-Host ""
Write-Host "=====================================================" -ForegroundColor Green
Write-Host "  Release $Version prete" -ForegroundColor Green
Write-Host "=====================================================" -ForegroundColor Green
Write-Host ""
if ($Upload) {
  Write-Host "  [DEPLOYEE] Pamela verra la banniere dans 6h max" -ForegroundColor Green
  Write-Host "  (ou immediatement au prochain demarrage de son app)." -ForegroundColor White
} else {
  Write-Host "Fichiers produits :" -ForegroundColor White
  Write-Host "  - $InstallerExe"
  Write-Host "  - $manifestPath"
  Write-Host ""
  Write-Host "Etape suivante - upload manuel sur Supabase :" -ForegroundColor Yellow
  Write-Host "  1. Storage -> bucket 'releases'"
  Write-Host "  2. Glisse-depose skyblue-setup-$Version.exe + manifest.json"
  Write-Host ""
  Write-Host "OU configure .secrets.local et relance avec -Upload pour tout automatiser." -ForegroundColor Yellow
}
Write-Host ""
