# ==============================================================
# Clone GitHub Repositories (Public, Private & Starred)
# --------------------------------------------------------------
# SETUP: Fill in your details in the CONFIGURATION section below
# then double-click run-clone.bat to run.
# IF RUNNING ON WINDOWS 11, RUN THIS Command in Powershell First: 
# Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
# If That Command Does not Work, Try this one:
# Set-ExecutionPolicy -Scope CurrentUser Unrestricted
# ALSO THIS SCRIPT REQUIRES GIT TO BE INSTALLED: https://git-scm.com/
# ==============================================================
# --------------------------------------------------------------
# CONFIGURATION — edit these values
# --------------------------------------------------------------

$Username        = "your_github_username"  # Your GitHub username
$Token           = "ghp_your_token_here"   # Your GitHub Personal Access Token (never commit a real one!)
$DateStamp       = Get-Date -Format "yyyyMMdd"           # Today's date, e.g. 20260616
$OutputDir       = "$PSScriptRoot\$DateStamp" # Where to save repos (dated folder)
$ZipWhenDone     = $true    # Zip the dated output folder when cloning finishes
$RemoveAfterZip  = $true # Delete the folder once the zip is created

# Set to $true to enable, $false to disable
$IncludeStarred  = $true   # Also clone your starred repositories
$GroupByLanguage = $false   # Organize repos into subfolders by language
$SkipPublic      = $false   # Skip your public repositories
$SkipPrivate     = $false   # Skip your private repositories
 
# --------------------------------------------------------------
 
# --- Setup headers ---
$headers = @{ "User-Agent" = "PowerShell-GitHubCloner" }
if ($Token -ne "" -and $Token -ne "ghp_your_token_here") {
    $headers["Authorization"] = "Bearer $Token"
}
 
# --- Check git is installed ---
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Error "Git is not installed or not in PATH. Please install Git from https://git-scm.com"
    exit 1
}
 
# --- Warn if no token provided ---
if ($Token -eq "" -or $Token -eq "ghp_your_token_here") {
    Write-Host "[WARNING] Token not set. Private repositories will not be accessible." -ForegroundColor Yellow
    Write-Host "          Edit clone-github-repos.ps1 and paste your token into the CONFIGURATION section." -ForegroundColor Yellow
    Write-Host "          Get a token at: https://github.com/settings/tokens`n" -ForegroundColor Yellow
}
 
# --- Helper: Paginated API fetch ---
function Get-GitHubPaged {
    param([string]$Url)
 
    $results = @()
    $page = 1
 
    while ($true) {
        $pagedUrl = "${Url}?per_page=100&page=$page&type=owner"
        try {
            $response = Invoke-RestMethod -Uri $pagedUrl -Headers $headers -Method Get
        } catch {
            Write-Error "API request failed for ${Url}: $_"
            return $results
        }
        if ($response.Count -eq 0) { break }
        $results += $response
        $page++
    }
    return $results
}
 
# --- Helper: Clone a list of repos into a subfolder ---
function Clone-Repos {
    param(
        [array]$Repos,
        [string]$Category
    )
 
    if ($Repos.Count -eq 0) {
        Write-Host "  No repositories found.`n" -ForegroundColor Yellow
        return @{ Success = 0; Skipped = 0; Failed = 0 }
    }
 
    Write-Host "  Found $($Repos.Count) repositories.`n" -ForegroundColor Green
 
    $success = 0; $skipped = 0; $failed = 0
 
    foreach ($repo in $Repos) {
        $name     = $repo.name
        $language = if ($repo.language) { $repo.language } else { "Unknown" }
        $private  = $repo.private
 
        # For private repos, embed token in clone URL for auth
        $cloneUrl = $repo.clone_url
        if ($private -and $Token -ne "" -and $Token -ne "ghp_your_token_here") {
            $cloneUrl = $cloneUrl -replace "https://", "https://$Token@"
        }
 
        # Build destination path
        if ($GroupByLanguage) {
            $dest = [System.IO.Path]::Combine($OutputDir, $Category, $language, $name)
        } else {
            $dest = [System.IO.Path]::Combine($OutputDir, $Category, $name)
        }
 
        if (Test-Path $dest) {
            Write-Host "  [SKIP] $name (already exists)" -ForegroundColor Yellow
            $skipped++
            continue
        }
 
        # Create parent folder if needed
        $parent = Split-Path $dest -Parent
        if (-not (Test-Path $parent)) {
            New-Item -ItemType Directory -Path $parent | Out-Null
        }
 
        $visibility = if ($private) { "private" } else { "public" }
        Write-Host "  [CLONE] $name  ($language, $visibility)" -ForegroundColor White
        git clone --quiet $cloneUrl $dest 2>&1
 
        if ($LASTEXITCODE -eq 0) {
            $success++
        } else {
            Write-Host "    Failed to clone $name" -ForegroundColor Red
            $failed++
        }
    }
 
    return @{ Success = $success; Skipped = $skipped; Failed = $failed }
}
 
# --- Create root output directory ---
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir | Out-Null
    Write-Host "Created directory: $OutputDir`n" -ForegroundColor Cyan
}
 
$totalSuccess = 0; $totalSkipped = 0; $totalFailed = 0
 
# ============================================================
# 1. OWN REPOS (public + private)
# ============================================================
if (-not $SkipPublic -or -not $SkipPrivate) {
 
    $reposUrl = "https://api.github.com/user/repos"
 
    Write-Host "Fetching your repositories..." -ForegroundColor Cyan
    $allMyRepos = Get-GitHubPaged -Url $reposUrl
 
    if (-not $SkipPublic -and -not $SkipPrivate) {
        $myRepos = $allMyRepos
    } elseif ($SkipPrivate) {
        $myRepos = $allMyRepos | Where-Object { -not $_.private }
    } elseif ($SkipPublic) {
        $myRepos = $allMyRepos | Where-Object { $_.private }
    }
 
    $publicCount  = ($myRepos | Where-Object { -not $_.private }).Count
    $privateCount = ($myRepos | Where-Object { $_.private }).Count
    Write-Host "  Public: $publicCount  |  Private: $privateCount" -ForegroundColor Gray
 
    $result = Clone-Repos -Repos $myRepos -Category "my-repos"
    $totalSuccess += $result.Success
    $totalSkipped += $result.Skipped
    $totalFailed  += $result.Failed
}
 
# ============================================================
# 2. STARRED REPOS
# ============================================================
if ($IncludeStarred) {
    Write-Host "Fetching starred repositories for '$Username'..." -ForegroundColor Cyan
    $starredRepos = Get-GitHubPaged -Url "https://api.github.com/users/$Username/starred"
 
    $result = Clone-Repos -Repos $starredRepos -Category "starred"
    $totalSuccess += $result.Success
    $totalSkipped += $result.Skipped
    $totalFailed  += $result.Failed
}
 
# ============================================================
# Summary
# ============================================================
Write-Host "`n--- Done ---" -ForegroundColor Cyan
Write-Host "  Cloned:  $totalSuccess" -ForegroundColor Green
Write-Host "  Skipped: $totalSkipped" -ForegroundColor Yellow
Write-Host "  Failed:  $totalFailed"  -ForegroundColor Red
Write-Host "  Output:  $(Resolve-Path $OutputDir)`n"

# ============================================================
# Zip the output folder
# ============================================================
if ($ZipWhenDone) {
    $zipPath = "$OutputDir.zip"
    if (Test-Path $zipPath) {
        $zipPath = "$OutputDir-$(Get-Date -Format 'HHmmss').zip"
    }

    $src   = (Resolve-Path $OutputDir).Path
    $zipOk = $false

    # Run the compression on a background runspace so we can animate here
    $ps = [PowerShell]::Create()
    [void]$ps.AddScript({
        param($Source, $Destination)
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::CreateFromDirectory(
            $Source,
            $Destination,
            [System.IO.Compression.CompressionLevel]::Optimal,
            $true)
    }).AddArgument($src).AddArgument($zipPath)

    $handle = $ps.BeginInvoke()
    $timer  = [System.Diagnostics.Stopwatch]::StartNew()
    $frames = '|','/','-','\'
    $i = 0

    while (-not $handle.IsCompleted) {
        $elapsed = "{0:mm\:ss}" -f $timer.Elapsed
        Write-Host "`r  $($frames[$i % 4])  Compressing...  $elapsed" -NoNewline -ForegroundColor Cyan
        $i++
        Start-Sleep -Milliseconds 120
    }

    $timer.Stop()
    Write-Host ("`r" + (' ' * 40) + "`r") -NoNewline   # clear the spinner line

    try {
        $ps.EndInvoke($handle)

        $sizeMB  = [math]::Round((Get-Item $zipPath).Length / 1MB, 1)
        $elapsed = "{0:mm\:ss}" -f $timer.Elapsed
        Write-Host "  Created: $zipPath ($sizeMB MB in $elapsed)" -ForegroundColor Green

        $zipOk = (Test-Path $zipPath) -and ((Get-Item $zipPath).Length -gt 1MB)
    } catch {
        $msg = if ($_.Exception.InnerException) { $_.Exception.InnerException.Message } else { $_.Exception.Message }
        Write-Host "  Zip failed: $msg" -ForegroundColor Red
        Write-Host "  The cloned folder is still intact at $OutputDir" -ForegroundColor Yellow
    } finally {
        $ps.Dispose()
    }

    if ($RemoveAfterZip -and $zipOk) {
        Write-Host "  Removing source folder..." -ForegroundColor Gray
        try {
            Remove-Item -Path $OutputDir -Recurse -Force -ErrorAction Stop
        } catch {
            # Fallback: rd handles read-only trees that Remove-Item chokes on
            & cmd /c "rd /s /q `"$OutputDir`"" 2>&1 | Out-Null
        }

        if (Test-Path $OutputDir) {
            Write-Host "  Could not remove $OutputDir - delete it manually." -ForegroundColor Red
        } else {
            Write-Host "  Removed source folder." -ForegroundColor Gray
        }
    } elseif ($RemoveAfterZip) {
        Write-Host "  Skipped folder removal (zip not verified)." -ForegroundColor Yellow
    }
}