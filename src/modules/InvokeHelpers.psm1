function Split-RenderingJobs {
    param (
        [object] $Scene
    )

    $imageWidth = $Scene.Camera.ImageWidth
    $aspectWidth = $Scene.Camera.AspectRatio.Split(":")[0]
    $aspectHeight = $Scene.Camera.AspectRatio.Split(":")[1]
    $aspectRatio = $aspectWidth / $aspectHeight
    $imageHeight = [int]($imageWidth / $aspectRatio)
    
    if($imageWidth -ge ([Console]::WindowWidth - 2)) {
        throw "Image width of $imageWidth is trying to render wider than the terminal window, try zooming out"
    }
    if($imageHeight -ge (([Console]::WindowHeight * 2) - 2)) {
        throw "Image height of $imageHeight is trying to render taller than the terminal window, try zooming out"
    }

    $jobs = @()
    for($i = 0; $i -lt $imageHeight; $i++) {
        $jobs += @{
            Line = $i
            Scene = $Scene
        }
    }

    return $jobs
}

function Send-JobsToSNS {
    param (
        [array] $Jobs
    )
    Write-Host "Jobs Sent to SNS: "
    $currentPosition = @{ X = $Host.UI.RawUI.CursorPosition.X + 18; Y = $Host.UI.RawUI.CursorPosition.Y - 1 }

    $snsTopicArn = Get-SNSTopic | Select-Object -ExpandProperty "TopicArn" | Where-Object { $_ -like "*raytracingjobs" }
    if($null -eq $snsTopicArn -or $snsTopicArn -isnot [string]) {
        Write-Error "SNS topic for '*raytracingjobs' could not be found. Expected a single ARN but found '$snsTopicArn'"
    }

    [Console]::CursorVisible = $false
    try {
        $jobsSent = 0
        $Jobs | ForEach-Object {
            [Console]::SetCursorPosition($currentPosition.X, $currentPosition.Y)
            Write-Host -ForegroundColor DarkGray "$([int]++$jobsSent)/$($jobs.Count)    "
            Publish-SNSMessage -Message ($_ | ConvertTo-Json -Depth 25) -TopicArn $snsTopicArn | Out-Null
        }
    } finally {
        [Console]::CursorVisible = $true
    }
}

function Wait-ForLambdaResults {
    param (
        [array] $Jobs,
        [int] $TimeoutMinutes = 5
    )

    Write-Host "Waiting for lambda processing..."
    $sqsQueueUrl = Get-SQSQueue | Where-Object { $_ -like "*/sqs-pwshraytracer-notifications" }
    $timeout = (Get-Date).AddMinutes($TimeoutMinutes)
    $jobsReceived = 0
    $results = @{}
    
    while($jobsReceived -lt $jobs.Count) {
        if((Get-Date) -ge $timeout) {
            Write-Error "Timed out waiting for all jobs to complete after $TimeoutMinutes minutes"
        }
        $message = Receive-SQSMessage -QueueUrl $sqsQueueUrl
        if($message) {
            $jobsReceived++
            $body = ($message.Body | ConvertFrom-Json -Depth 25)
            Write-Verbose "$($body.requestPayload.Records[0].Sns.Message) "
            if($body.deliveryError) {
                Write-Host -ForegroundColor Red $body.deliveryError.errorMessage
            } elseif($body.responsePayload.errorMessage) {
                Write-Host -ForegroundColor Red ($body.responsePayload | ConvertTo-Json -Depth 25)
            } else {
                Write-Verbose ($body.responsePayload | ConvertTo-Json -Depth 25)
                $results[[int]$body.responsePayload.Line] = $body.responsePayload.Pixels
            }
            Remove-SQSMessage -QueueUrl $sqsQueueUrl -ReceiptHandle $message.ReceiptHandle -Force | Out-Null
        }
    }

    return $results
}

function Invoke-RenderToConsole {
    param (
        [object] $Results
    )

    for($i = 0; $i -lt $Results.Count; $i += 2) {
        $fgLine = $Results.($i+1)
        $bgLine = $Results.$i
        for($x = 0; $x -lt $fgLine.Count; $x++) {
            $fg = $fgLine[$x]
            $bg = $bgLine[$x]
            Write-Host -NoNewline "$([Char]27)[38;2;$($fg.R);$($fg.G);$($fg.B)m$([Char]27)[48;2;$($bg.R);$($bg.G);$($bg.B)m$([Char]0x2584)$([Char]27)[0m"
        }
        Write-Host ""
    }
}