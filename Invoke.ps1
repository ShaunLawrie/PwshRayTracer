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
$jobs = @(1) #,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1)

$snsTopicArn = Get-SNSTopic | Select-Object -ExpandProperty "TopicArn" | Where-Object { $_ -like "*raytracingjobs" }
if($null -eq $snsTopicArn -or $snsTopicArn -isnot [string]) {
    Write-Error "SNS topic for '*raytracingjobs' could not be found. Expected a single ARN but found '$snsTopicArn'"
}

Write-Host -NoNewline "Jobs Sent to SNS: "
$currentPosition = $Host.UI.RawUI.CursorPosition
[Console]::CursorVisible = $false
$jobsSent = 0
$jobs | ForEach-Object {
    [Console]::SetCursorPosition($currentPosition.X, $currentPosition.Y)
    Write-Host -ForegroundColor DarkGray "$([int]++$jobsSent)/$($jobs.Count)    "
    Publish-SNSMessage -Message "message $($jobsSent.ToString('000'))" -TopicArn $snsTopicArn | Out-Null
}

Write-Host "Waiting for processing..."
$sqsQueueUrl = Get-SQSQueue | Where-Object { $_ -like "*/sqs-pwshraytracer-notifications" }
$timeout = (Get-Date).AddMinutes(5)
$jobsReceived = 0
while($jobsReceived -lt $jobs.Count) {
    if((Get-Date) -ge $timeout) {
        Write-Error "Timed out waiting for all jobs to complete"
    }
    $message = Receive-SQSMessage -QueueUrl $sqsQueueUrl
    if($message) {
        $jobsReceived++
        $body = ($message.Body | ConvertFrom-Json -Depth 25)
        Write-Host -NoNewline "Job: "
        Write-Host -NoNewline -ForegroundColor DarkGray "$($body.requestPayload.Records[0].Sns.Message) "
        if($body.deliveryError) {
            Write-Host -ForegroundColor DarkRed $body.deliveryError.errorMessage
        } else {
            Write-Host -ForegroundColor DarkGreen $body.responsePayload
        }
        Remove-SQSMessage -QueueUrl $sqsQueueUrl -ReceiptHandle $message.ReceiptHandle -Force | Out-Null
    }
}