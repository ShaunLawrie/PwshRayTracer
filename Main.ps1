param(
    [int] $Animation = 2,
    [int] $Frames = 30,
    [int] $Width = [Console]::WindowWidth,
    [int] $Height = [Console]::WindowHeight
)

$ErrorActionPreference = "Stop"
Import-Module "$PSScriptRoot/Modules/Plasma.psm1" -Force
Import-Module "$PSScriptRoot/Modules/RayTracer.psm1" -Force
Import-Module "$PSScriptRoot/Modules/Plasma.fast.psm1" -Force
Import-Module "$PSScriptRoot/Modules/ConsoleDrawing.psm1" -Force

Clear-HostAndHideCursor

switch($Animation) {
    0 { Invoke-DrawPlasma -Frames 20 -Width $Width -Height ($Height - 1) }
    1 { Invoke-DrawPlasmaFast -Frames 20 -Width $Width -Height ($Height - 1) }
    2 { Invoke-RayTracer }
    default { Write-Host "Please provide a valid animation index" }
}
