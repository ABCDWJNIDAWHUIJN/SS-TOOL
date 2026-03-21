$hwidFolder = "$env:APPDATA\Microsoft\Windows\Caches"
$hwidDatabase = "$hwidFolder\hwid_alts.json"

function Get-HWID {
    try {
        $computerInfo = Get-WmiObject Win32_ComputerSystemProduct
        $uuid = $computerInfo.UUID
        $drive = Get-WmiObject Win32_DiskDrive | Where-Object { $_.Index -eq 0 }
        $driveSerial = $drive.SerialNumber
        $hwid = "$uuid-$driveSerial"
        $hash = [System.BitConverter]::ToString([System.Security.Cryptography.MD5]::Create().ComputeHash([System.Text.Encoding]::UTF8.GetBytes($hwid)))
        return $hash -replace '-', ''
    }
    catch { return "UNKNOWN" }
}

$currentHWID = Get-HWID

$hwidAltDatabase = @{}
if (Test-Path $hwidDatabase) {
    try {
        $databaseContent = Get-Content $hwidDatabase -Raw
        $hwidAltDatabase = $databaseContent | ConvertFrom-Json
        if ($hwidAltDatabase -eq $null) { $hwidAltDatabase = @{} }
    } catch { $hwidAltDatabase = @{} }
}

Write-Host @"
========================================
    HWID ALT MANAGEMENT TOOL
========================================
"@ -ForegroundColor Cyan

Write-Host "`nCurrent PC HWID: $currentHWID" -ForegroundColor Yellow

Write-Host "`n=== STORED HWIDs ===" -ForegroundColor Cyan
$hwidList = @()
$counter = 1
foreach ($hwidKey in $hwidAltDatabase.PSObject.Properties.Name) {
    if ($hwidKey -ne "Keys" -and $hwidKey -ne "Values" -and $hwidKey -ne "Count" -and $hwidKey -ne "IsReadOnly" -and $hwidKey -ne "IsFixedSize" -and $hwidKey -ne "IsSynchronized" -and $hwidKey -ne "SyncRoot") {
        $altCount = ($hwidAltDatabase.$hwidKey.PSObject.Properties.Name | Where-Object { $_ -ne "Keys" -and $_ -ne "Values" -and $_ -ne "Count" -and $_ -ne "IsReadOnly" -and $_ -ne "IsFixedSize" -and $_ -ne "IsSynchronized" -and $_ -ne "SyncRoot" }).Count
        $isCurrent = if ($hwidKey -eq $currentHWID) { " (CURRENT PC)" } else { "" }
        Write-Host "$counter. $hwidKey - $altCount alts$isCurrent" -ForegroundColor White
        $hwidList += $hwidKey
        $counter++
    }
}

if ($hwidList.Count -eq 0) {
    Write-Host "No HWIDs found in database." -ForegroundColor Yellow
    exit
}

Write-Host "`nOptions:" -ForegroundColor Cyan
Write-Host "1. Delete ALL alts from a HWID (cannot undo)" -ForegroundColor White
Write-Host "2. Delete a specific alt from a HWID" -ForegroundColor White
Write-Host "3. View alts for a specific HWID" -ForegroundColor White
Write-Host "4. Remove entire HWID from database" -ForegroundColor White
Write-Host "5. Exit" -ForegroundColor White

$choice = Read-Host "`nEnter your choice (1-5)"

switch ($choice) {
    "1" {
        Write-Host "`nEnter the NUMBER of the HWID to delete alts from:" -ForegroundColor Yellow
        for ($i = 0; $i -lt $hwidList.Count; $i++) {
            Write-Host "$($i+1). $($hwidList[$i])" -ForegroundColor White
        }
        $hwidNum = Read-Host "Number"
        
        if ($hwidNum -match '^\d+$' -and [int]$hwidNum -ge 1 -and [int]$hwidNum -le $hwidList.Count) {
            $selectedHWID = $hwidList[[int]$hwidNum - 1]
            
            $confirm = Read-Host "Are you sure you want to delete ALL alts for HWID: $selectedHWID? (yes/no)"
            if ($confirm -eq "yes") {
                $hwidAltDatabase.PSObject.Properties.Remove($selectedHWID)
                $hwidAltDatabase | ConvertTo-Json -Depth 10 | Set-Content -Path $hwidDatabase -Force
                Write-Host "All alts for HWID $selectedHWID have been deleted!" -ForegroundColor Green
            } else {
                Write-Host "Operation cancelled." -ForegroundColor Yellow
            }
        } else {
            Write-Host "Invalid input. Please enter a number between 1 and $($hwidList.Count)." -ForegroundColor Red
        }
    }
    
    "2" {
        Write-Host "`nEnter the NUMBER of the HWID to manage:" -ForegroundColor Yellow
        for ($i = 0; $i -lt $hwidList.Count; $i++) {
            Write-Host "$($i+1). $($hwidList[$i])" -ForegroundColor White
        }
        $hwidNum = Read-Host "Number"
        
        if ($hwidNum -match '^\d+$' -and [int]$hwidNum -ge 1 -and [int]$hwidNum -le $hwidList.Count) {
            $selectedHWID = $hwidList[[int]$hwidNum - 1]
            
            $altList = @()
            $altCounter = 1
            foreach ($alt in $hwidAltDatabase.$selectedHWID.PSObject.Properties.Name) {
                if ($alt -ne "Keys" -and $alt -ne "Values" -and $alt -ne "Count" -and $alt -ne "IsReadOnly" -and $alt -ne "IsFixedSize" -and $alt -ne "IsSynchronized" -and $alt -ne "SyncRoot") {
                    $firstSeen = $hwidAltDatabase.$selectedHWID.$alt
                    Write-Host "$altCounter. $alt (First detected: $firstSeen)" -ForegroundColor White
                    $altList += $alt
                    $altCounter++
                }
            }
            
            if ($altList.Count -eq 0) {
                Write-Host "No alts found for this HWID." -ForegroundColor Yellow
                break
            }
            
            $altNum = Read-Host "`nEnter the NUMBER of the alt to delete"
            if ($altNum -match '^\d+$' -and [int]$altNum -ge 1 -and [int]$altNum -le $altList.Count) {
                $selectedAlt = $altList[[int]$altNum - 1]
                
                $confirm = Read-Host "Delete alt '$selectedAlt' from HWID $selectedHWID? (yes/no)"
                if ($confirm -eq "yes") {
                    $hwidAltDatabase.$selectedHWID.PSObject.Properties.Remove($selectedAlt)
                    
                    $remainingAlts = ($hwidAltDatabase.$selectedHWID.PSObject.Properties.Name | Where-Object { $_ -ne "Keys" -and $_ -ne "Values" -and $_ -ne "Count" -and $_ -ne "IsReadOnly" -and $_ -ne "IsFixedSize" -and $_ -ne "IsSynchronized" -and $_ -ne "SyncRoot" }).Count
                    if ($remainingAlts -eq 0) {
                        $hwidAltDatabase.PSObject.Properties.Remove($selectedHWID)
                        Write-Host "No alts remaining. HWID entry removed." -ForegroundColor Yellow
                    }
                    
                    $hwidAltDatabase | ConvertTo-Json -Depth 10 | Set-Content -Path $hwidDatabase -Force
                    Write-Host "Alt '$selectedAlt' has been deleted!" -ForegroundColor Green
                }
            } else {
                Write-Host "Invalid input. Please enter a number between 1 and $($altList.Count)." -ForegroundColor Red
            }
        } else {
            Write-Host "Invalid input. Please enter a number between 1 and $($hwidList.Count)." -ForegroundColor Red
        }
    }
    
    "3" {
        Write-Host "`nEnter the NUMBER of the HWID to view:" -ForegroundColor Yellow
        for ($i = 0; $i -lt $hwidList.Count; $i++) {
            Write-Host "$($i+1). $($hwidList[$i])" -ForegroundColor White
        }
        $hwidNum = Read-Host "Number"
        
        if ($hwidNum -match '^\d+$' -and [int]$hwidNum -ge 1 -and [int]$hwidNum -le $hwidList.Count) {
            $selectedHWID = $hwidList[[int]$hwidNum - 1]
            
            Write-Host "`nAlts for HWID ${selectedHWID}:" -ForegroundColor Cyan
            $altCounter = 1
            foreach ($alt in $hwidAltDatabase.$selectedHWID.PSObject.Properties.Name | Sort-Object) {
                if ($alt -ne "Keys" -and $alt -ne "Values" -and $alt -ne "Count" -and $alt -ne "IsReadOnly" -and $alt -ne "IsFixedSize" -and $alt -ne "IsSynchronized" -and $alt -ne "SyncRoot") {
                    $firstSeen = $hwidAltDatabase.$selectedHWID.$alt
                    Write-Host "$altCounter. $alt (First detected: $firstSeen)" -ForegroundColor White
                    $altCounter++
                }
            }
        } else {
            Write-Host "Invalid input. Please enter a number between 1 and $($hwidList.Count)." -ForegroundColor Red
        }
    }
    
    "4" {
        Write-Host "`nEnter the NUMBER of the HWID to remove from database:" -ForegroundColor Yellow
        for ($i = 0; $i -lt $hwidList.Count; $i++) {
            Write-Host "$($i+1). $($hwidList[$i])" -ForegroundColor White
        }
        $hwidNum = Read-Host "Number"
        
        if ($hwidNum -match '^\d+$' -and [int]$hwidNum -ge 1 -and [int]$hwidNum -le $hwidList.Count) {
            $selectedHWID = $hwidList[[int]$hwidNum - 1]
            
            $confirm = Read-Host "Are you sure you want to remove HWID $selectedHWID from the database? (yes/no)"
            if ($confirm -eq "yes") {
                $hwidAltDatabase.PSObject.Properties.Remove($selectedHWID)
                $hwidAltDatabase | ConvertTo-Json -Depth 10 | Set-Content -Path $hwidDatabase -Force
                Write-Host "HWID $selectedHWID has been removed from the database!" -ForegroundColor Green
            }
        } else {
            Write-Host "Invalid input. Please enter a number between 1 and $($hwidList.Count)." -ForegroundColor Red
        }
    }
    
    "5" { exit }
}
