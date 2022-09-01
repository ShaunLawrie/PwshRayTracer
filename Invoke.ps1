#Requires -Version 7
param (
    [string] $Scene = "src/scenes/RayTracingInAWeekend.json",
    [string] $Region = "ap-southeast-2",
    [string] $ProfileName = "default"
)

$ErrorActionPreference = "Stop"

if(!(Get-Command "Get-SNSTopic" -ErrorAction "SilentlyContinue")) {
    Write-Error "Required AWS Powershell Tools are missing [AWS.Tools.SimpleNotificationService, AWS.Tools.SQS]`nSee https://docs.aws.amazon.com/powershell/latest/userguide/pstools-getting-set-up-windows.html"
}

Set-AWSCredential -ProfileName $ProfileName

Import-Module "./src/modules/InvokeHelpers.psm1" -Force

$data = Get-Content -Path $Scene | ConvertFrom-Json

Write-Host -NoNewline "Scene: "
Write-Host -ForegroundColor DarkGray "$Scene"
Write-Host -NoNewline "Camera: "
Write-Host -ForegroundColor DarkGray ($data.Camera | ConvertTo-Json -Compress -Depth 5)
Write-Host -NoNewline "Objects: "
Write-Host -ForegroundColor DarkGray ($data.Objects.Count)

$jobs = Split-RenderingJobs -Scene $data
$start = Get-Date
$imageHeight = Get-ImageHeight -Scene $data

# Invoke lambda
Send-JobsToSNS -Jobs $jobs -Region $Region
$receipts = Wait-ForLambdaResults -Jobs $jobs -LiveRender -ImageHeight $imageHeight -ImageWidth $data.Camera.ImageWidth -Region $Region
$end = Get-Date
$secondsDuration = (New-TimeSpan -Start $start -End $end).TotalSeconds
$cameraRaysTracedPerSecond = ($data.Camera.ImageWidth * $imageHeight * $data.Camera.SamplesPerPixel) / $secondsDuration
$pixelsPerSecond = ($data.Camera.ImageWidth * $imageHeight) / $secondsDuration
Write-Host "Lambda completed at $end in $([int]$secondsDuration) seconds, $([int]$cameraRaysTracedPerSecond) camera rays traced/sec, $([int]$pixelsPerSecond) pixels/sec"
Write-Host "Removing SQS messages"
$sqsQueueUrl = Get-SQSQueue -Region "ap-southeast-2" | Where-Object { $_ -like "*/sqs-pwshraytracer-notifications" }
try {
    # Purge is faster but can only be run once every 60 seconds
    Clear-SQSQueue -Region $Region -QueueUrl $sqsQueueUrl -Force
} catch {
    # Fallback to removing each receipt if purge fails
    foreach($receipt in $receipts) {
        Remove-SQSMessage -Region $Region -QueueUrl $sqsQueueUrl -ReceiptHandle $receipt -Force
    }
}