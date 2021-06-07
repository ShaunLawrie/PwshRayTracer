param(
    [int] $Animation = 2,
    [int] $Frames = 30,
    [int] $Width = [Console]::WindowWidth,
    [int] $Height = [Console]::WindowHeight
)

$ErrorActionPreference = "Stop"
Import-Module "$PSScriptRoot/Modules/ConsoleDrawing.psm1" -Force

Clear-HostAndHideCursor
while ($true) {
    try {
        Get-ChildItem -Path "$PSScriptRoot/Modules" -Filter "*.psm1" | Foreach-Object { Import-Module $_.PsPath -Force }
        switch($Animation) {
            0 { Invoke-DrawPlasma -Frames 20 -Width $Width -Height ($Height - 1) }
            1 { Invoke-DrawPlasmaFast -Frames 20 -Width $Width -Height ($Height - 1) }
            2 { Invoke-RayTracer }
            default { Write-Error "Please provide a valid animation index"; }
        }
    } catch {
        Write-Warning "Failed to load a module, retrying in 1 second: $_"
    } finally {
        Start-Sleep -Seconds 1
    }
}
