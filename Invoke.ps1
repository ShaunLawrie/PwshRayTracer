param (
    [string] $Scene = "scenes/raytracinginaweekend.json"
)

Write-Host -NoNewline "Scene: "
Write-Host -ForegroundColor DarkGray "$Scene"
$data = Get-Content -Path $Scene | ConvertFrom-Json
Write-Host -NoNewline "Camera: "
Write-Host -ForegroundColor DarkGray ($data.Camera | ConvertTo-Json -Compress -Depth 5)
Write-Host -NoNewline "Objects: "
$padding = ""
$data.Objects | ForEach-Object {
    Write-Host -ForegroundColor DarkGray ($padding + ($_ | ConvertTo-Json -Compress -Depth 5))
    $padding = "         "
}
$jobs = @(1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1)

$snsTopicArn = Get-SNSTopic | Select-Object -ExpandProperty "TopicArn" | Where-Object { $_ -like "*raytracingjobs" }
if($null -eq $snsTopicArn -or $snsTopicArn -isnot [string]) {
    Write-Error "SNS topic for '*raytracingjobs' could not be found. Expected a single ARN but found '$snsTopicArn'"
}
Write-Host -NoNewline "Jobs Sent to SNS: "
$currentPosition = $Host.UI.RawUI.CursorPosition
[Console]::CursorVisible = $false
$jobsSent = 0
$jobs | ForEach-Object {
    Start-Sleep -Milliseconds 250
    [Console]::SetCursorPosition($currentPosition.X, $currentPosition.Y)
    Write-Host -ForegroundColor DarkGray "$([int]++$jobsSent)/$($jobs.Count)    "
    Publish-SNSMessage -Message "hello: $_" -TopicArn $snsTopicArn | Out-Null
}

