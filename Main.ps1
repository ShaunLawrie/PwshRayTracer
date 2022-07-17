$ErrorActionPreference = "Stop"
Get-ChildItem -Path "$PSScriptRoot/Modules" -Filter "*.psm1" | Foreach-Object { Import-Module $_.PsPath -Force }

Clear-HostAndHideCursor
while ($true) {
    try {
        Get-ChildItem -Path "$PSScriptRoot/Modules" -Filter "*.psm1" | Foreach-Object { Import-Module $_.PsPath -Force }
        Invoke-Renderer
    } catch {
        Write-Warning "Failed to load a module, retrying in 1 second: $_"
    } finally {
        Start-Sleep -Seconds 1
    }
}
