# Open folders
explorer shell:recent
explorer $env:TEMP
explorer shell:windows

# Launch all tools
Start-Process powershell -ArgumentList '-NoExit', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', 'Invoke-Expression (Invoke-RestMethod ''https://raw.githubusercontent.com/Unknown-dll/Tool-Collector/refs/heads/main/Tools%20Collector'')'

Start-Process powershell -ArgumentList '-NoExit', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', 'Invoke-Expression (Invoke-RestMethod ''https://raw.githubusercontent.com/praiselily/lilith-ps/refs/heads/main/Services.ps1'')'

Start-Process powershell -ArgumentList '-NoExit', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', 'Invoke-Expression (Invoke-RestMethod ''https://raw.githubusercontent.com/MeowTonynoh/MeowModAnalyzer/main/MeowModAnalyzer.ps1'')'

Start-Process powershell -ArgumentList '-NoExit', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', 'Invoke-Expression (Invoke-RestMethod ''https://raw.githubusercontent.com/ABCDWJNIDAWHUIJN/SS-TOOL/main/Alt-Detector.ps1'')'
