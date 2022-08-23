param (
    [switch] $SkipRuntimeLayer
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$gitInstalled = Get-Command "git" -ErrorAction "SilentlyContinue"
if(!$gitInstalled) {
    Write-Error "Git is required to be installed to clone the awslabs/aws-lambda-powershell-runtime repository"
}

if(!(Test-Path "$PSScriptRoot/aws-lambda-powershell-runtime")) {
    Write-Host "Cloning the awslabs powershell runtime repository so we can build the powershell runtime"
    git clone git@github.com:awslabs/aws-lambda-powershell-runtime.git "$PSScriptRoot/aws-lambda-powershell-runtime"
}

if(!$SkipRuntimeLayer) {
    $pwshLayerLocation = "$PSScriptRoot/artifacts/pwsh_lambda_layer_payload.zip"
    if(Test-Path $pwshLayerLocation) {
        Remove-Item $pwshLayerLocation
    }
    Write-Host "Build the layer (this downloads the microsoft provided powershell binaries into the layer source folder for the pwsh-runtime)"
    & $PSScriptRoot\aws-lambda-powershell-runtime\powershell-runtime\build-PwshRuntimeLayer.ps1
    Write-Host "Build a zip for terraform to upload as a custom lambda layer for the powershell runtime"
    Compress-Archive -Path "$PSScriptRoot/aws-lambda-powershell-runtime/powershell-runtime/pwsh-runtime/*" -DestinationPath $pwshLayerLocation
}

$functionPayloadLocation = "$PSScriptRoot/artifacts/pwsh_lambda_function_payload.zip"
if(Test-Path $functionPayloadLocation) {
    Remove-Item $functionPayloadLocation
}
Write-Host "Build a zip for terraform to upload as the lambda function from the code in src/lambda/*"
Compress-Archive -Path "$PSScriptRoot/src/lambda/*" -DestinationPath $functionPayloadLocation
