$ErrorActionPreference = "Stop"

function Get-ImageHeight {
    param(
        [object] $Scene
    )

    $imageWidth = $Scene.Camera.ImageWidth
    $aspectWidth = $Scene.Camera.AspectRatio.Split(":")[0]
    $aspectHeight = $Scene.Camera.AspectRatio.Split(":")[1]
    $aspectRatio = $aspectWidth / $aspectHeight
    $imageHeight = [int]($imageWidth / $aspectRatio)

    return $imageHeight
}

function Split-RenderingJobs {
    param (
        [object] $Scene,
        [int] $PixelsPerLambda = 10
    )

    $imageWidth = $Scene.Camera.ImageWidth
    $imageHeight = Get-ImageHeight -Scene $Scene
    
    if($imageWidth -ge ([Console]::WindowWidth - 2)) {
        throw "Image width of $imageWidth is trying to render wider than the terminal window, try zooming out"
    }
    if($imageHeight -ge (([Console]::WindowHeight * 2) - 2)) {
        throw "Image height of $imageHeight is trying to render taller than the terminal window, try zooming out"
    }

    $jobs = @()
    for($i = 0; $i -lt $imageHeight; $i++) {
        for($j = 0; $j -lt $imageWidth; $j += $PixelsPerLambda) {
            $jobs += @{
                Line = $i
                Start = $j
                End = [Math]::Min(($j + $PixelsPerLambda), $imageWidth)
                Scene = $Scene
            }
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
        $limit = 5
        $jobsSent = 0
        for($i = 0; $i -lt $Jobs.Count; $i += $limit) {
            $batch = @()
            for($j = 0; $j -lt $limit -and ($i + $j) -le $Jobs.Count; $j++) {
                $entry = New-Object Amazon.SimpleNotificationService.Model.PublishBatchRequestEntry
                $entry.Id = (New-Guid).Guid.ToString()
                $entry.Message = $Jobs[($i + $j)] | ConvertTo-Json -Depth 25
                $batch += $entry
                $jobsSent++
            }
            Publish-SNSBatch -TopicArn $snsTopicArn -PublishBatchRequestEntry $batch | Out-Null
            [Console]::SetCursorPosition($currentPosition.X, $currentPosition.Y)
            Write-Host -ForegroundColor DarkGray "$jobsSent/$($Jobs.Count)    "
        }
    } finally {
        [Console]::CursorVisible = $true
    }
}

function Wait-ForLambdaResults {
    param (
        [array] $Jobs,
        [int] $TimeoutMinutes = 10
    )

    Write-Host "Waiting for lambda results: "
    $currentPosition = @{ X = $Host.UI.RawUI.CursorPosition.X + 28; Y = $Host.UI.RawUI.CursorPosition.Y - 1 }
    $sqsQueueUrl = Get-SQSQueue | Where-Object { $_ -like "*/sqs-pwshraytracer-notifications" }
    $timeout = (Get-Date).AddMinutes($TimeoutMinutes)
    $jobsReceived = 0
    $results = @{}
    
    while($jobsReceived -lt $jobs.Count) {
        if((Get-Date) -ge $timeout) {
            Write-Warning "Timed out waiting for all jobs to complete after $TimeoutMinutes minutes"
            break
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
                $key = [int]$body.responsePayload.Line
                $start = [int]$body.responsePayload.Start
                if(!$results.ContainsKey($key)) {
                    $results[$key] = @{}
                }
                $results[$key][$start] = $body.responsePayload.Pixels
            }
            Remove-SQSMessage -QueueUrl $sqsQueueUrl -ReceiptHandle $message.ReceiptHandle -Force | Out-Null
            [Console]::SetCursorPosition($currentPosition.X, $currentPosition.Y)
            Write-Host -ForegroundColor DarkGray "$jobsReceived/$($Jobs.Count)    "
        }
    }

    return $results
}

function Invoke-RenderToConsole {
    param (
        [object] $Results
    )

    for($i = 0; $i -lt $Results.Count; $i += 2) {
        $fgLine = $Results[$i+1].GetEnumerator() | Sort-Object { $_.Key } | Select-Object -ExpandProperty Value
        $bgLine = $Results[$i].GetEnumerator() | Sort-Object { $_.Key } | Select-Object -ExpandProperty Value
        for($x = 0; $x -lt $fgLine.Count; $x++) {
            $fg = $fgLine[$x]
            $bg = $bgLine[$x]
            Write-Host -NoNewline "$([Char]27)[38;2;$($fg.R);$($fg.G);$($fg.B)m$([Char]27)[48;2;$($bg.R);$($bg.G);$($bg.B)m$([Char]0x2584)$([Char]27)[0m"
        }
        Write-Host ""
    }
}