param(
    [int] $Animation = 0,
    [int] $Frames = 30
)

$ErrorActionPreference = "Stop"
Import-Module "$PSScriptRoot/Modules/Plasma.psm1" -Force
Import-Module "$PSScriptRoot/Modules/Plasma.fast.psm1" -Force

Clear-HostAndHideCursor

switch($Animation) {
    0 { Invoke-DrawPlasma -Frames 20 -Width ([Console]::WindowWidth) -Height ([Console]::WindowHeight-1) }
    1 { Invoke-DrawPlasmaFast -Frames 20 -Width ([Console]::WindowWidth) -Height ([Console]::WindowHeight-1) }
    default { Write-Host "Please provide a valid animation index" }
}
