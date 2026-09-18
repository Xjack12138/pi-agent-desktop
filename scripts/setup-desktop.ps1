$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$repoRoot = Split-Path -Parent $PSScriptRoot
$toolsRoot = Join-Path $repoRoot ".tools"
$downloads = Join-Path $toolsRoot "downloads"
$nodeRoot = Join-Path $toolsRoot "node"
$cargoHome = Join-Path $toolsRoot "cargo"
$rustupHome = Join-Path $toolsRoot "rustup"
New-Item -ItemType Directory -Force -Path $downloads | Out-Null

function Install-PortableNode {
  $nodeExe = Join-Path $nodeRoot "node.exe"
  if (Test-Path -LiteralPath $nodeExe) {
    Write-Host "[ok] Portable Node is already installed."
    return
  }

  Write-Host "[1/4] Downloading portable Node.js 22..."
  $checksumText = (Invoke-WebRequest "https://nodejs.org/dist/latest-v22.x/SHASUMS256.txt" -UseBasicParsing).Content
  $match = [regex]::Match($checksumText, '(?m)^([0-9a-f]{64})\s+(node-v[^\s]+-win-x64\.zip)$')
  if (-not $match.Success) { throw "Could not resolve the latest Node.js 22 Windows archive." }
  $expectedHash = $match.Groups[1].Value
  $archiveName = $match.Groups[2].Value
  $archivePath = Join-Path $downloads $archiveName
  Invoke-WebRequest "https://nodejs.org/dist/latest-v22.x/$archiveName" -OutFile $archivePath -UseBasicParsing
  $actualHash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
  if ($actualHash -ne $expectedHash) { throw "Node.js archive checksum mismatch." }

  $extractRoot = Join-Path $toolsRoot "node-extract"
  Remove-Item -LiteralPath $extractRoot -Recurse -Force -ErrorAction SilentlyContinue
  Expand-Archive -LiteralPath $archivePath -DestinationPath $extractRoot -Force
  $extracted = Get-ChildItem -LiteralPath $extractRoot -Directory | Select-Object -First 1
  if (-not $extracted) { throw "Node.js archive did not contain a directory." }
  Move-Item -LiteralPath $extracted.FullName -Destination $nodeRoot
  Remove-Item -LiteralPath $extractRoot -Recurse -Force
  Write-Host "[ok] Node.js installed in .tools/node."
}

function Install-PortableRust {
  $cargoExe = Join-Path $cargoHome "bin\cargo.exe"
  if (Test-Path -LiteralPath $cargoExe) {
    Write-Host "[ok] Portable Rust is already installed."
    return
  }

  Write-Host "[2/4] Downloading portable Rust..."
  $rustupInstaller = Join-Path $downloads "rustup-init.exe"
  Invoke-WebRequest "https://win.rustup.rs/x86_64" -OutFile $rustupInstaller -UseBasicParsing
  $env:CARGO_HOME = $cargoHome
  $env:RUSTUP_HOME = $rustupHome
  & $rustupInstaller -y --no-modify-path --profile minimal --default-toolchain stable
  if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $cargoExe)) {
    throw "Rust installation failed."
  }
  Write-Host "[ok] Rust installed in .tools."
}

function Test-VcBuildTools {
  $vswherePaths = @(
    "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe",
    "$env:ProgramFiles\Microsoft Visual Studio\Installer\vswhere.exe"
  )
  $vswhere = $vswherePaths | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
  if (-not $vswhere) { return $false }
  $installation = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
  return -not [string]::IsNullOrWhiteSpace(($installation | Select-Object -First 1))
}

function Install-VcBuildTools {
  if (Test-VcBuildTools) {
    Write-Host "[ok] Microsoft C++ Build Tools are already installed."
    return
  }

  Write-Host "[3/4] Installing Microsoft C++ Build Tools. Approve the Windows prompt..."
  $installer = Join-Path $downloads "vs_BuildTools.exe"
  Invoke-WebRequest "https://aka.ms/vs/17/release/vs_BuildTools.exe" -OutFile $installer -UseBasicParsing
  $process = Start-Process -FilePath $installer -ArgumentList @(
    "--passive", "--wait", "--norestart",
    "--add", "Microsoft.VisualStudio.Workload.VCTools",
    "--includeRecommended"
  ) -Verb RunAs -Wait -PassThru
  if ($process.ExitCode -notin 0, 3010) { throw "C++ Build Tools installer exited with code $($process.ExitCode)." }
  if (-not (Test-VcBuildTools)) { throw "C++ Build Tools were not detected after installation." }
  Write-Host "[ok] Microsoft C++ Build Tools installed."
}

function Test-WebView2 {
  $keys = @(
    "HKLM:\SOFTWARE\Microsoft\EdgeUpdate\Clients\{F1E7E2A6-AF1B-4F9A-B93A-38A847D84881}",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\{F1E7E2A6-AF1B-4F9A-B93A-38A847D84881}",
    "HKCU:\SOFTWARE\Microsoft\EdgeUpdate\Clients\{F1E7E2A6-AF1B-4F9A-B93A-38A847D84881}"
  )
  if ($keys | Where-Object { Test-Path $_ } | Select-Object -First 1) { return $true }

  $uninstallRoots = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
  )
  $installed = Get-ItemProperty $uninstallRoots -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName -eq "Microsoft Edge WebView2 Runtime" } |
    Select-Object -First 1
  if ($installed) { return $true }

  $runtimeRoot = "${env:ProgramFiles(x86)}\Microsoft\EdgeWebView\Application"
  return [bool](Get-ChildItem -LiteralPath $runtimeRoot -Filter "msedgewebview2.exe" -File -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1)
}

function Install-WebView2 {
  if (Test-WebView2) {
    Write-Host "[ok] WebView2 Runtime is already installed."
    return
  }

  Write-Host "[4/4] Installing Microsoft WebView2 Runtime..."
  $winget = Get-Command "winget.exe" -ErrorAction SilentlyContinue
  if ($winget) {
    & $winget.Source install --id Microsoft.EdgeWebView2Runtime --exact --silent --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -eq 0 -and (Test-WebView2)) {
      Write-Host "[ok] WebView2 Runtime installed."
      return
    }
    Write-Host "winget could not install WebView2; trying Microsoft's bootstrapper..."
  }

  Write-Host "Approve the Windows prompt if shown..."
  $installer = Join-Path $downloads "MicrosoftEdgeWebview2Setup.exe"
  Invoke-WebRequest "https://go.microsoft.com/fwlink/p/?LinkId=2124703" -OutFile $installer -UseBasicParsing
  $process = Start-Process -FilePath $installer -ArgumentList "/silent", "/install" -Verb RunAs -Wait -PassThru
  if ($process.ExitCode -ne 0) { throw "WebView2 installer exited with code $($process.ExitCode)." }
  Write-Host "[ok] WebView2 Runtime installed."
}

Install-PortableNode
Install-PortableRust
Install-VcBuildTools
Install-WebView2

$env:Path = "$nodeRoot;$cargoHome\bin;$env:Path"
Write-Host "Installing project packages with npm ci..."
Push-Location $repoRoot
try {
  & (Join-Path $nodeRoot "npm.cmd") ci
  if ($LASTEXITCODE -ne 0) { throw "npm ci failed." }
} finally {
  Pop-Location
}
