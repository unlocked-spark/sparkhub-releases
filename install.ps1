<#
Spark Hub installer for Windows (x64). No administrator rights needed.

  irm https://raw.githubusercontent.com/unlocked-spark/sparkhub-releases/main/install.ps1 | iex

Options are read from environment variables when piped into iex, or from parameters when
the script is saved to a file and run directly:
  SPARKHUB_VERSION / -Version vX.Y.Z   install that release instead of the latest one
  SPARKHUB_CHANNEL / -Channel nightly  install the newest build from the main branch
  SPARKHUB_INSTALL_DIR / -InstallDir   install directory (default: %LOCALAPPDATA%\Programs\SparkHub)
  -Uninstall                           remove the binary and the PATH entry this script added
#>
param(
  [string]$Version = $env:SPARKHUB_VERSION,
  [string]$Channel = $(if ($env:SPARKHUB_CHANNEL) { $env:SPARKHUB_CHANNEL } else { "latest" }),
  [string]$InstallDir = $(if ($env:SPARKHUB_INSTALL_DIR) { $env:SPARKHUB_INSTALL_DIR } else { Join-Path $env:LOCALAPPDATA "Programs\SparkHub" }),
  [switch]$Uninstall
)

$ErrorActionPreference = "Stop"
# The progress bar of Invoke-WebRequest is drawn in place, so screen readers never announce it.
$ProgressPreference = "SilentlyContinue"
$Repo = "unlocked-spark/sparkhub-releases"
$Asset = "sparkhub-windows-x64.exe"
$Target = Join-Path $InstallDir "sparkhub.exe"

function Fail([string]$Message) {
  Write-Host "sparkhub installer: $Message"
  exit 1
}

# Downloads with one progress line every 10 percent, at most once every 5 seconds,
# so a screen reader reads each step as a normal line.
function Save-Download([string]$Uri, [string]$OutFile) {
  $request = [Net.HttpWebRequest]::Create($Uri)
  $request.UserAgent = "sparkhub-installer"
  $response = $request.GetResponse()
  try {
    $total = $response.ContentLength
    if ($total -gt 0) { Write-Host ("Size {0:N1} MB." -f ($total / 1MB)) }
    $in = $response.GetResponseStream()
    $out = [IO.File]::Create($OutFile)
    try {
      $buffer = New-Object byte[] 65536
      $done = 0
      $nextStep = 10
      $lastReport = Get-Date
      while (($read = $in.Read($buffer, 0, $buffer.Length)) -gt 0) {
        $out.Write($buffer, 0, $read)
        $done += $read
        if ($total -le 0) { continue }
        $percent = [int][Math]::Floor($done * 100 / $total)
        if ($percent -ge $nextStep -and $percent -lt 100 -and ((Get-Date) - $lastReport).TotalSeconds -ge 5) {
          Write-Host "Downloaded $percent percent."
          $lastReport = Get-Date
          $nextStep = ([Math]::Floor($percent / 10) + 1) * 10
        }
      }
    } finally {
      $out.Dispose()
      $in.Dispose()
    }
  } finally {
    $response.Close()
  }
}

function Get-UserPath {
  [Environment]::GetEnvironmentVariable("Path", "User")
}

function Set-UserPath([string]$Value) {
  [Environment]::SetEnvironmentVariable("Path", $Value, "User")
}

if ($Uninstall) {
  if (Test-Path $Target) { Remove-Item -Force $Target }
  $parts = (Get-UserPath) -split ";" | Where-Object { $_ -and ($_.TrimEnd("\") -ne $InstallDir.TrimEnd("\")) }
  Set-UserPath ($parts -join ";")
  Write-Host "Spark Hub was removed from $InstallDir. Installed games and settings stay in your data directory."
  exit 0
}

$arch = $env:PROCESSOR_ARCHITECTURE
if ($arch -ne "AMD64" -and $arch -ne "ARM64") { Fail "Spark Hub needs a 64-bit Windows (found $arch)." }

if ($Version) {
  $base = "https://github.com/$Repo/releases/download/$Version"
} elseif ($Channel -eq "nightly") {
  $base = "https://github.com/$Repo/releases/download/nightly"
} elseif ($Channel -eq "latest") {
  $base = "https://github.com/$Repo/releases/latest/download"
} else {
  Fail "Unknown channel $Channel; use latest or nightly."
}

try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch {}

$work = Join-Path ([IO.Path]::GetTempPath()) ("sparkhub-install-" + [IO.Path]::GetRandomFileName())
New-Item -ItemType Directory -Path $work | Out-Null
try {
  Write-Host "Downloading $Asset from $base"
  try {
    Save-Download "$base/$Asset" (Join-Path $work $Asset)
    Invoke-WebRequest -UseBasicParsing -Uri "$base/$Asset.sha256" -OutFile (Join-Path $work "$Asset.sha256")
  } catch {
    Fail "Download failed: $($_.Exception.Message). If no release exists yet, set SPARKHUB_CHANNEL=nightly and try again."
  }
  $expected = ((Get-Content (Join-Path $work "$Asset.sha256") -First 1) -split "\s+")[0].ToLower()
  $actual = (Get-FileHash -Algorithm SHA256 (Join-Path $work $Asset)).Hash.ToLower()
  if ($expected -ne $actual) { Fail "Checksum mismatch: expected $expected, got $actual. The download was discarded." }
  Write-Host "Checksum verified."

  New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
  Move-Item -Force (Join-Path $work $Asset) $Target
  Write-Host "Installed $Target"
} finally {
  Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue
}

$userPath = Get-UserPath
$onPath = ($userPath -split ";") | Where-Object { $_ -and ($_.TrimEnd("\") -eq $InstallDir.TrimEnd("\")) }
if (-not $onPath) {
  Set-UserPath (($userPath.TrimEnd(";")) + ";" + $InstallDir).TrimStart(";")
  Write-Host "Added $InstallDir to your PATH. Open a new terminal to use the sparkhub command."
}
if (-not (($env:Path -split ";") -contains $InstallDir)) { $env:Path = "$env:Path;$InstallDir" }

$installed = & $Target --version
Write-Host "Spark Hub $installed is ready. Try: sparkhub search swamp"
