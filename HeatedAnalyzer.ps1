# Heated Mod Analyzer v1.0

param(
    [string]$ModPath,
    [switch]$SkipDeepScan,
    [switch]$ExportJson
)

Clear-Host

# ========== HEATED BANNER ==========
$HeatedBanner = @"

  ██╗  ██╗███████╗ █████╗ ████████╗███████╗██████╗
  ██║  ██║██╔════╝██╔══██╗╚══██╔══╝██╔════╝██╔══██╗
  ███████║█████╗  ███████║   ██║   █████╗  ██║  ██║
  ██╔══██║██╔══╝  ██╔══██║   ██║   ██╔══╝  ██║  ██║
  ██║  ██║███████╗██║  ██║   ██║   ███████╗██████╔╝
  ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝   ╚═╝   ╚══════╝╚═════╝

   █████╗ ███╗   ██╗ █████╗ ██╗   ██╗   ██╗███████╗███████╗██████╗
  ██╔══██╗████╗  ██║██╔══██╗██║   ╚██╗ ██╔╝╚══███╔╝██╔════╝██╔══██╗
  ███████║██╔██╗ ██║███████║██║    ╚████╔╝   ███╔╝ █████╗  ██████╔╝
  ██╔══██║██║╚██╗██║██╔══██║██║     ╚██╔╝   ███╔╝  ██╔══╝  ██╔══██╗
  ██║  ██║██║ ╚████║██║  ██║███████╗ ██║    ███████╗███████╗██║  ██║
  ╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝  ╚═╝╚══════╝ ╚═╝    ╚══════╝╚══════╝╚═╝  ╚═╝

"@

Write-Host $HeatedBanner -ForegroundColor Red
Write-Host ""
Write-Host "                Made with " -NoNewline -ForegroundColor Gray
Write-Host "♥ " -NoNewline -ForegroundColor Red
Write-Host "by " -NoNewline -ForegroundColor Gray
Write-Host "Heated" -ForegroundColor Red
Write-Host ""
Write-Host ("━" * 76) -ForegroundColor DarkRed
Write-Host ""

# ========== PATH SELECTION ==========
Write-Host " Enter path to mods folder:" -ForegroundColor Cyan
Write-Host " (Press Enter to use default Minecraft mods folder)" -ForegroundColor DarkGray
$inputPath = Read-Host " PATH"

if ([string]::IsNullOrWhiteSpace($inputPath)) {
    $inputPath = "$env:APPDATA\.minecraft\mods"
    Write-Host " Continuing with: $inputPath" -ForegroundColor White
}

if (-not (Test-Path $inputPath -PathType Container)) {
    Write-Host " Invalid Path! Directory does not exist." -ForegroundColor Red
    Write-Host " Press any key to exit..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}

Write-Host ""
Write-Host ("━" * 76) -ForegroundColor DarkRed
Write-Host ""

# ========== MINECRAFT UPTIME CHECK ==========
$mcProcess = Get-Process javaw -ErrorAction SilentlyContinue
if (-not $mcProcess) {
    $mcProcess = Get-Process java -ErrorAction SilentlyContinue
}

if ($mcProcess) {
    try {
        $startTime = $mcProcess.StartTime
        $uptime = (Get-Date) - $startTime
        Write-Host " MINECRAFT UPTIME" -ForegroundColor DarkCyan
        Write-Host "    $($mcProcess.Name) PID $($mcProcess.Id) started at $startTime" -ForegroundColor Gray
        Write-Host "    Running for: $($uptime.Hours)h $($uptime.Minutes)m $($uptime.Seconds)s" -ForegroundColor Gray
        Write-Host ""
    } catch {}
}

# ========== FUNCTIONS ==========

function Get-ZoneIdentifier {
    param ([string]$filePath)
    $ads = Get-Content -Raw -Stream Zone.Identifier $filePath -ErrorAction SilentlyContinue
    if ($ads -match "HostUrl=(.+)") {
        return $matches[1]
    }
    return $null
}

function Get-FileDates {
    param([string]$FilePath)
    
    $file = Get-Item $FilePath -ErrorAction SilentlyContinue
    if ($file) {
        return @{
            Created = $file.CreationTime
            Modified = $file.LastWriteTime
            Accessed = $file.LastAccessTime
        }
    }
    return @{
        Created = "Unknown"
        Modified = "Unknown"
        Accessed = "Unknown"
    }
}

function Get-SourceDescription {
    param([string]$ZoneUrl)
    
    if (-not $ZoneUrl) { return "Unknown" }
    
    if ($ZoneUrl -match "discord") { return "Discord" }
    if ($ZoneUrl -match "modrinth") { return "Modrinth" }
    if ($ZoneUrl -match "curseforge") { return "CurseForge" }
    if ($ZoneUrl -match "github") { return "GitHub" }
    if ($ZoneUrl -match "mediafire") { return "MediaFire" }
    if ($ZoneUrl -match "dropbox") { return "Dropbox" }
    if ($ZoneUrl -match "drive.google") { return "Google Drive" }
    if ($ZoneUrl -match "mega") { return "MEGA" }
    if ($ZoneUrl -match "vape") { return "Vape Client" }
    if ($ZoneUrl -match "intent.store") { return "Intent Store" }
    if ($ZoneUrl -match "rise.today") { return "Rise Client" }
    if ($ZoneUrl -match "doomsday") { return "Doomsday Client" }
    
    if ($ZoneUrl -match "https?://([^/]+)") {
        return $matches[1]
    }
    
    return "Unknown"
}

function Get-SHA1 {
    param ([string]$filePath)
    return (Get-FileHash -Path $filePath -Algorithm SHA1).Hash
}

function Test-Modrinth {
    param ([string]$hash)
    try {
        $response = Invoke-RestMethod -Uri "https://api.modrinth.com/v2/version_file/$hash" -Method Get -UseBasicParsing -ErrorAction Stop -TimeoutSec 5
        if ($response.project_id) {
            $project = Invoke-RestMethod -Uri "https://api.modrinth.com/v2/project/$($response.project_id)" -Method Get -UseBasicParsing -ErrorAction Stop -TimeoutSec 5
            return @{ Name = $project.title; Slug = $project.slug }
        }
    } catch {}
    return $null
}

function Test-Megabase {
    param ([string]$hash)
    try {
        $response = Invoke-RestMethod -Uri "https://megabase.vercel.app/api/query?hash=$hash" -Method Get -UseBasicParsing -ErrorAction Stop -TimeoutSec 5
        if (-not $response.error) {
            return @{ Name = $response.data.name; Slug = $response.data.slug }
        }
    } catch {}
    return $null
}

# ========== DEEP SCAN FUNCTION ==========
function Invoke-DeepScan {
    param([string]$FilePath)
    
    $foundPatterns = [System.Collections.Generic.HashSet[string]]::new()
    $tempDir = Join-Path $env:TEMP "heated_deepscan_$(Get-Random)"
    
    $cheatPatterns = @(
        "KillAura", "ClickAura", "TriggerBot", "MultiAura", "ForceField", "AimAssist", "AimBot", "SilentAim",
        "CrystalAura", "AutoCrystal", "AutoHitCrystal", "AnchorAura", "AutoAnchor", "DoubleAnchor", "SafeAnchor",
        "BowAimbot", "AutoCrit", "Criticals", "ReachHack", "LongReach", "HitboxExpand", "AntiKB", "NoKnockback",
        "Velocity", "GrimDisabler", "AutoTotem", "HoverTotem", "InventoryTotem", "OffhandTotem", "ShieldBreaker",
        "WTap", "JumpReset", "AxeSpam", "MaceSwap", "FlyHack", "PacketFly", "SpeedHack", "NoFall",
        "Scaffold", "ScaffoldWalk", "ElytraFly", "ElytraSwap", "PlayerESP", "XRay", "Freecam", "FullBright",
        "Disabler", "TimerHack", "FakeLag", "PingSpoof", "SelfDestruct", "ChestStealer", "AutoArmor", "AutoPot",
        "vape.gg", "vape v4", "vapeclient", "intent.store", "rise.today", "riseclient.com", "meteorclient",
        "wurstclient", "liquidbounce", "doomsdayclient", "DoomsdayClient", "aristois", "impactclient"
    )
    
    try {
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($FilePath, $tempDir)
        
        $files = Get-ChildItem -Path $tempDir -Recurse -Include *.class, *.json, *.properties, *.txt, *.cfg -ErrorAction SilentlyContinue
        
        foreach ($file in $files) {
            try {
                $content = Get-Content -Path $file.FullName -Raw -ErrorAction SilentlyContinue
                if ($content) {
                    foreach ($pattern in $cheatPatterns) {
                        if ($content -match "\b$([regex]::Escape($pattern))\b") {
                            $foundPatterns.Add($pattern) | Out-Null
                        }
                    }
                }
            } catch {}
        }
        
        $nestedJars = Get-ChildItem -Path "$tempDir\META-INF\jars" -Filter *.jar -ErrorAction SilentlyContinue
        foreach ($nested in $nestedJars) {
            $nestedResult = Invoke-DeepScan -FilePath $nested.FullName
            foreach ($pattern in $nestedResult) {
                $foundPatterns.Add($pattern) | Out-Null
            }
        }
        
    } finally {
        if (Test-Path $tempDir) {
            Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    
    return $foundPatterns
}

# ========== MAIN SCAN ==========
$jarFiles = Get-ChildItem -Path $inputPath -Filter *.jar -File

if ($jarFiles.Count -eq 0) {
    Write-Host " No mods found in: $inputPath" -ForegroundColor Red
    Write-Host " Press any key to exit..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 0
}

Write-Host " Found $($jarFiles.Count) mod(s) to analyze" -ForegroundColor Green
Write-Host ""

$spinner = @("⣾", "⣽", "⣻", "⢿", "⡿", "⣟", "⣯", "⣷")

# ========== PASS 1: VERIFICATION ==========
Write-Host " PASS 1: Verifying mods against databases..." -ForegroundColor Cyan
Write-Host ("─" * 76) -ForegroundColor DarkGray

$verifiedMods = @()
$unknownMods = @()
$counter = 0

foreach ($file in $jarFiles) {
    $counter++
    $spin = $spinner[$counter % $spinner.Length]
    Write-Host "`r [$spin] Verifying: $counter / $($jarFiles.Count) - $($file.Name)" -NoNewline -ForegroundColor Yellow
    
    $hash = Get-SHA1 -filePath $file.FullName
    $fileDates = Get-FileDates -FilePath $file.FullName
    
    $modrinthData = Test-Modrinth -hash $hash
    if ($modrinthData) {
        $verifiedMods += [PSCustomObject]@{
            FileName = $file.Name
            ModName = $modrinthData.Name
            Hash = $hash
            RawSource = Get-ZoneIdentifier -filePath $file.FullName
            SourceDesc = Get-SourceDescription -ZoneUrl (Get-ZoneIdentifier -filePath $file.FullName)
            FilePath = $file.FullName
            FileSize = [math]::Round($file.Length / 1KB, 2)
            CreatedDate = $fileDates.Created
            ModifiedDate = $fileDates.Modified
        }
        continue
    }
    
    $megabaseData = Test-Megabase -hash $hash
    if ($megabaseData) {
        $verifiedMods += [PSCustomObject]@{
            FileName = $file.Name
            ModName = $megabaseData.Name
            Hash = $hash
            RawSource = Get-ZoneIdentifier -filePath $file.FullName
            SourceDesc = Get-SourceDescription -ZoneUrl (Get-ZoneIdentifier -filePath $file.FullName)
            FilePath = $file.FullName
            FileSize = [math]::Round($file.Length / 1KB, 2)
            CreatedDate = $fileDates.Created
            ModifiedDate = $fileDates.Modified
        }
        continue
    }
    
    $unknownMods += [PSCustomObject]@{
        FileName = $file.Name
        FilePath = $file.FullName
        Hash = $hash
        RawSource = Get-ZoneIdentifier -filePath $file.FullName
        SourceDesc = Get-SourceDescription -ZoneUrl (Get-ZoneIdentifier -filePath $file.FullName)
        FileSize = [math]::Round($file.Length / 1KB, 2)
        CreatedDate = $fileDates.Created
        ModifiedDate = $fileDates.Modified
    }
}

Write-Host "`r" + " " * 100 + "`r" -NoNewline

# ========== PASS 2: DEEP SCAN ==========
Write-Host ""
Write-Host " PASS 2: Deep scanning unknown mods..." -ForegroundColor Cyan
Write-Host ("─" * 76) -ForegroundColor DarkGray

$cheatMods = @()
$cleanUnknownMods = @()
$counter = 0
$totalUnknown = $unknownMods.Count

if ($SkipDeepScan) {
    $cleanUnknownMods = $unknownMods
    Write-Host " Deep scan skipped by user" -ForegroundColor Yellow
} elseif ($totalUnknown -eq 0) {
    Write-Host " No unknown mods to deep scan!" -ForegroundColor Green
} else {
    foreach ($mod in $unknownMods) {
        $counter++
        $spin = $spinner[$counter % $spinner.Length]
        Write-Host "`r [$spin] Deep scanning: $counter / $totalUnknown - $($mod.FileName)" -NoNewline -ForegroundColor Yellow
        
        $deepResult = Invoke-DeepScan -FilePath $mod.FilePath
        
        if ($deepResult.Count -gt 0) {
            $cheatMods += [PSCustomObject]@{
                FileName = $mod.FileName
                FilePath = $mod.FilePath
                Hash = $mod.Hash
                RawSource = $mod.RawSource
                SourceDesc = $mod.SourceDesc
                FileSize = $mod.FileSize
                CreatedDate = $mod.CreatedDate
                ModifiedDate = $mod.ModifiedDate
                PatternsFound = $deepResult
                PatternCount = $deepResult.Count
            }
        } else {
            $cleanUnknownMods += $mod
        }
    }
}

Write-Host "`r" + " " * 100 + "`r" -NoNewline

# ========== RESULTS ==========
Clear-Host
Write-Host $HeatedBanner -ForegroundColor Red
Write-Host ""
Write-Host "                Made with " -NoNewline -ForegroundColor Gray
Write-Host "♥ " -NoNewline -ForegroundColor Red
Write-Host "by " -NoNewline -ForegroundColor Gray
Write-Host "Heated" -ForegroundColor Red
Write-Host ""
Write-Host ("━" * 76) -ForegroundColor DarkRed
Write-Host ""

# Verified Mods
Write-Host " VERIFIED MODS ($($verifiedMods.Count))" -ForegroundColor Green
Write-Host ("─" * 76) -ForegroundColor DarkGray
if ($verifiedMods.Count -gt 0) {
    foreach ($mod in $verifiedMods) {
        Write-Host "  $($mod.ModName)" -ForegroundColor White
        Write-Host "     File: $($mod.FileName)" -ForegroundColor Gray
        Write-Host "     Size: $($mod.FileSize) KB" -ForegroundColor DarkGray
        Write-Host "     Downloaded: $($mod.CreatedDate)" -ForegroundColor DarkGray
        Write-Host "     Location: $($mod.FilePath)" -ForegroundColor DarkGray
        if ($mod.SourceDesc -and $mod.SourceDesc -ne "Unknown") {
            Write-Host "     Source: $($mod.SourceDesc)" -ForegroundColor Cyan
        }
        Write-Host ""
    }
} else {
    Write-Host "  No verified mods found." -ForegroundColor Gray
    Write-Host ""
}

# Unknown Clean Mods
Write-Host " UNKNOWN MODS (No cheats detected) ($($cleanUnknownMods.Count))" -ForegroundColor Yellow
Write-Host ("─" * 76) -ForegroundColor DarkGray
if ($cleanUnknownMods.Count -gt 0) {
    foreach ($mod in $cleanUnknownMods) {
        Write-Host "  $($mod.FileName)" -ForegroundColor Yellow
        Write-Host "     Size: $($mod.FileSize) KB" -ForegroundColor DarkGray
        Write-Host "     Downloaded: $($mod.CreatedDate)" -ForegroundColor DarkGray
        Write-Host "     Location: $($mod.FilePath)" -ForegroundColor DarkGray
        if ($mod.SourceDesc -and $mod.SourceDesc -ne "Unknown") {
            Write-Host "     Source: $($mod.SourceDesc)" -ForegroundColor Cyan
        }
        Write-Host ""
    }
} else {
    Write-Host "  No unknown clean mods." -ForegroundColor Gray
    Write-Host ""
}

# Cheat Mods
Write-Host " CHEAT MODS DETECTED ($($cheatMods.Count))" -ForegroundColor Red
Write-Host ("━" * 76) -ForegroundColor Red
if ($cheatMods.Count -gt 0) {
    foreach ($mod in $cheatMods) {
        Write-Host ""
        Write-Host "  ┌─────────────────────────────────────────────────────────" -ForegroundColor DarkRed
        Write-Host "  │ $($mod.FileName)" -ForegroundColor Red
        Write-Host "  │" -ForegroundColor DarkRed
        Write-Host "  │  LOCATION:" -ForegroundColor Yellow
        Write-Host "  │     $($mod.FilePath)" -ForegroundColor Gray
        Write-Host "  │" -ForegroundColor DarkRed
        Write-Host "  │  DOWNLOADED:" -ForegroundColor Yellow
        Write-Host "  │     $($mod.CreatedDate)" -ForegroundColor Gray
        Write-Host "  │" -ForegroundColor DarkRed
        Write-Host "  │  SIZE: $($mod.FileSize) KB" -ForegroundColor Gray
        Write-Host "  │  SHA1: $($mod.Hash)" -ForegroundColor Gray
        Write-Host "  │" -ForegroundColor DarkRed
        
        if ($mod.SourceDesc -and $mod.SourceDesc -ne "Unknown") {
            Write-Host "  │  DOWNLOAD SOURCE:" -ForegroundColor Yellow
            Write-Host "  │     $($mod.SourceDesc)" -ForegroundColor Cyan
            Write-Host "  │" -ForegroundColor DarkRed
        }
        
        Write-Host "  │  DETECTED PATTERNS ($($mod.PatternCount)):" -ForegroundColor Red
        foreach ($pattern in ($mod.PatternsFound | Select-Object -First 15)) {
            Write-Host "  │     • $pattern" -ForegroundColor DarkRed
        }
        if ($mod.PatternCount -gt 15) {
            Write-Host "  │     ... and $($mod.PatternCount - 15) more" -ForegroundColor DarkGray
        }
        Write-Host "  │" -ForegroundColor DarkRed
        Write-Host "  └─────────────────────────────────────────────────────────" -ForegroundColor DarkRed
        Write-Host ""
    }
} else {
    Write-Host ""
    Write-Host "  No cheat mods detected! System is clean." -ForegroundColor Green
    Write-Host ""
}

# Summary
Write-Host ("━" * 76) -ForegroundColor DarkRed
Write-Host ""
Write-Host " SUMMARY" -ForegroundColor Cyan
Write-Host ("─" * 76) -ForegroundColor DarkGray
Write-Host "     Verified (Safe): $($verifiedMods.Count)" -ForegroundColor Green
Write-Host "     Unknown (Clean): $($cleanUnknownMods.Count)" -ForegroundColor Yellow
Write-Host "     Cheat Mods: $($cheatMods.Count)" -ForegroundColor Red
Write-Host "     Total Scanned: $($jarFiles.Count)" -ForegroundColor White
Write-Host ""

# Export option
if ($ExportJson) {
    $exportData = @{
        ScanTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        ModPath = $inputPath
        TotalMods = $jarFiles.Count
        VerifiedMods = $verifiedMods | Select-Object FileName, ModName, Hash, SourceDesc, CreatedDate
        UnknownMods = $cleanUnknownMods | Select-Object FileName, Hash, SourceDesc, CreatedDate
        CheatMods = $cheatMods | Select-Object FileName, FilePath, Hash, SourceDesc, CreatedDate, PatternCount
    }
    $jsonPath = "$env:USERPROFILE\Desktop\heated_scan_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
    $exportData | ConvertTo-Json -Depth 10 | Out-File -FilePath $jsonPath
    Write-Host " Results exported to: $jsonPath" -ForegroundColor Green
    Write-Host ""
}

Write-Host " Press any key to exit..." -ForegroundColor DarkGray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
