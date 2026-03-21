# Admin Script to Clear HWID - Run this on YOUR computer
param(
    [string]$hwidToClear
)

$hwidListPath = "$env:APPDATA\Microsoft\Windows\Caches\hwid_list.dat"

if (-not $hwidToClear) {
    Write-Host "Usage: .\Clear-HWID.ps1 -hwidToClear 'HWID_HERE'" -ForegroundColor Yellow
    Write-Host "Or enter HWID to clear:" -ForegroundColor Cyan
    $hwidToClear = Read-Host "HWID"
}

# Load existing cleared HWIDs
$clearedHWIDs = @{}
if (Test-Path $hwidListPath) {
    try {
        $encrypted = Get-Content $hwidListPath -Raw
        $bytes = [System.Convert]::FromBase64String($encrypted)
        $decrypted = [System.Text.Encoding]::UTF8.GetString($bytes)
        $clearedHWIDs = $decrypted | ConvertFrom-Json
    }
    catch {
        $clearedHWIDs = @{}
    }
}

# Add HWID to cleared list
$clearedHWIDs[$hwidToClear] = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")

# Save the cleared list
$json = $clearedHWIDs | ConvertTo-Json
$bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
$encrypted = [System.Convert]::ToBase64String($bytes)
Set-Content -Path $hwidListPath -Value $encrypted -Force

Write-Host "HWID: $hwidToClear has been added to clear list!" -ForegroundColor Green

# Optional: Send confirmation to webhook
$webhookUrl = "https://discord.com/api/webhooks/1484660761065164941/zLCj9R1yBHopZUV9UflUrB_NS-aWOy9_DOcjB1-Djan2iHoXSyPaZCcCh9pZPMfG9UmN"
$message = "**HWID CLEAR COMMAND EXECUTED**`n**Cleared HWID:** $hwidToClear`n**Time:** $(Get-Date)`n**Admin:** $env:COMPUTERNAME"
$payload = @{content = $message; username = "HWID Admin"} | ConvertTo-Json
Invoke-RestMethod -Uri $webhookUrl -Method Post -Body $payload -ContentType "application/json" -ErrorAction SilentlyContinue
