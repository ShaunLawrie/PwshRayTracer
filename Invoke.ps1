#Requires -Version 7
param (
    [string] $Scene = "src/scenes/RayTracingInAWeekend.json"
)

$ErrorActionPreference = "Stop"

if(!(Get-Command "Get-SNSTopic" -ErrorAction "SilentlyContinue")) {
    Write-Error "Required AWS Powershell Tools are missing [AWS.Tools.SimpleNotificationService, AWS.Tools.SQS]`nSee https://docs.aws.amazon.com/powershell/latest/userguide/pstools-getting-set-up-windows.html"
}

Import-Module "./src/modules/InvokeHelpers.psm1" -Force

$data = Get-Content -Path $Scene | ConvertFrom-Json

Write-Host -NoNewline "Scene: "
Write-Host -ForegroundColor DarkGray "$Scene"
Write-Host -NoNewline "Camera: "
Write-Host -ForegroundColor DarkGray ($data.Camera | ConvertTo-Json -Compress -Depth 5)
Write-Host -NoNewline "Objects: "
Write-Host -ForegroundColor DarkGray ($data.Objects.Count)

$jobs = Split-RenderingJobs -Scene $data

Send-JobsToSNS -Jobs $jobs
$start = Get-Date
$results = Wait-ForLambdaResults -Jobs $jobs
Invoke-RenderToConsole -Results $results
Write-Host "Lambda total time $((New-TimeSpan -Start $start -End (Get-Date)).Seconds) seconds"