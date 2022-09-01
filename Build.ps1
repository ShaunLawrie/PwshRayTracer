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
    Write-Host "Build the layer (this downloads the Microsoft provided PowerShell binaries into the layer source folder for the pwsh-runtime)"
    & $PSScriptRoot\aws-lambda-powershell-runtime\powershell-runtime\build-PwshRuntimeLayer.ps1
    Write-Host "Build a zip for terraform to upload as a custom lambda layer for the powershell runtime"
    Compress-Archive -Path "$PSScriptRoot/aws-lambda-powershell-runtime/powershell-runtime/pwsh-runtime/*" -DestinationPath $pwshLayerLocation

    $pwshToolsLayerLocation = "$PSScriptRoot/artifacts/pwsh_lambda_tools_layer_payload.zip"
    if(Test-Path $pwshToolsLayerLocation) {
        Remove-Item $pwshToolsLayerLocation
    }
    Write-Host "Build the AWS tools layer (this downloads the AWS provided powershell binaries)"
    New-Item -ItemType Directory "$PSScriptRoot\aws-lambda-powershell-runtime\powershell-modules\AWSToolsforPowerShell\AWS.Tools.S3EventBridge\stage" -Force | Out-Null
    & "$PSScriptRoot\aws-lambda-powershell-runtime\powershell-modules\AWSToolsforPowerShell\AWS.Tools.S3EventBridge\build-AWSToolsLayer.ps1"
    Write-Host "Build a zip for terraform to upload as a custom lambda layer for the powershell AWS tools"
    Compress-Archive -Path "$PSScriptRoot/aws-lambda-powershell-runtime/powershell-modules/AWSToolsforPowerShell/AWS.Tools.S3EventBridge/modules" -DestinationPath $pwshToolsLayerLocation
}

$functionPayloadLocation = "$PSScriptRoot/artifacts/pwsh_lambda_function_payload.zip"
if(Test-Path $functionPayloadLocation) {
    Remove-Item $functionPayloadLocation
}
Write-Host "Build a zip for terraform to upload as the lambda function from the code in src/lambda/*"
Compress-Archive -Path "$PSScriptRoot/src/lambda/*" -DestinationPath $functionPayloadLocation
