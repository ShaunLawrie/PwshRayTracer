$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$gitInstalled = Get-Command "git" -ErrorAction "SilentlyContinue"
if(!$gitInstalled) {
    Write-Error "Git is required to be installed to clone the awslabs/aws-lambda-powershell-runtime repository"
}

Write-Host -ForegroundColor Green "Clean up the artifacts folder"
Get-ChildItem "$PSScriptRoot/artifacts/" -Exclude ".gitkeep" | Remove-Item
if(!(Test-Path "$PSScriptRoot/aws-lambda-powershell-runtime")) {
    Write-Host -ForegroundColor Green "Cloning the awslabs powershell runtime repository so we can build the powershell runtime"
    git clone git@github.com:awslabs/aws-lambda-powershell-runtime.git "$PSScriptRoot/aws-lambda-powershell-runtime"
}
Write-Host -ForegroundColor Green "Build the layer (this downloads the microsoft provided powershell binaries into the layer source folder for the pws-runtime)"
& $PSScriptRoot\aws-lambda-powershell-runtime\powershell-runtime\build-PwshRuntimeLayer.ps1
Write-Host -ForegroundColor Green "Build a zip for terraform to upload as a custom lambda layer for the powershell runtime"
Compress-Archive -Path "$PSScriptRoot/aws-lambda-powershell-runtime/powershell-runtime/pwsh-runtime/*" -DestinationPath "$PSScriptRoot/artifacts/pwsh_lambda_layer_payload.zip"
Write-Host -ForegroundColor Green "Build a zip for terraform to upload as the lambda function from the code in lambda/*"
Compress-Archive -Path "$PSScriptRoot/lambda/*" -DestinationPath "$PSScriptRoot/artifacts/pwsh_lambda_function_payload.zip"
