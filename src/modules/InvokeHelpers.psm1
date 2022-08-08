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
        [int] $PixelsPerLambda = 48
    )

    $imageWidth = $Scene.Camera.ImageWidth
    $imageHeight = Get-ImageHeight -Scene $Scene
    
    $windowWidthLimit = [Console]::WindowWidth - 2
    if($imageWidth -ge $windowWidthLimit) {
        throw "Image width of $imageWidth is trying to render wider than the terminal window ($windowWidthLimit), try zooming out"
    }
    $windowHeightLimit = ([Console]::WindowHeight * 2) - 2
    if($imageHeight -ge $windowHeightLimit) {
        throw "Image height of $imageHeight is trying to render taller than the terminal window ($windowHeightLimit), try zooming out"
    }
    
    $jobs = @()
    for($i = 0; $i -le $imageHeight; $i++) {
        for($j = 0; $j -lt $imageWidth; $j += $PixelsPerLambda) {
            $jobs += @{
                Line = $i
                Start = $j
                End = [Math]::Min(($j + $PixelsPerLambda - 1), $imageWidth - 1)
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
        $limit = 8
        $jobsSent = 0
        for($i = 0; $i -lt $Jobs.Count; $i += $limit) {
            $batch = @()
            for($j = 0; $j -lt $limit -and ($i + $j) -lt $Jobs.Count; $j++) {
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
        [switch] $LiveRender,
        [int] $ImageHeight,
        [int] $ImageWidth,
        [int] $TimeoutMinutes = 10
    )

    [Console]::CursorVisible = $false

    if($LiveRender -and (!$ImageHeight -or !$ImageWidth)) {
        Write-Error "ImageHeight and ImageWidth are required for live rendering"
    }

    $receipts = @()
    $liveRenderResults = @{}

    Write-Host "Waiting for lambda results: "
    for($y = 0; $y -lt $ImageHeight; $y++) {
        $liveRenderResults[$y] = @{
            Top = @{}
            Bottom = @{}
        }
    }
    $yOffset = ($ImageHeight / 2) + 2
    0..([int]($ImageHeight / 2)) | Foreach-Object {
        $line = $_ * 2
        if($line -eq $ImageHeight) {
            Write-Host -NoNewline -ForegroundColor DarkGray "  $(($line+1).ToString('000'))   "
        } else {
            Write-Host -NoNewline -ForegroundColor DarkGray "$(($line+1).ToString('000'))-$(($line+2).ToString('000')) "
        }
        Write-Host ("$([Char]27)[38;2;25;25;25m$([Char]27)[48;2;25;25;25m" + ("x" * $ImageWidth) + "$([Char]27)[0m")
    }
    $endPosition = $Host.UI.RawUI.CursorPosition
    $currentPosition = @{ X = $Host.UI.RawUI.CursorPosition.X + 28; Y = $Host.UI.RawUI.CursorPosition.Y - $yOffset }
    $canvasTopLeft = @{ X = $Host.UI.RawUI.CursorPosition.X + 8; Y = $Host.UI.RawUI.CursorPosition.Y - $yOffset + 1 }
    $sqsQueueUrl = Get-SQSQueue | Where-Object { $_ -like "*/sqs-pwshraytracer-notifications" }
    $timeout = (Get-Date).AddMinutes($TimeoutMinutes)
    $jobsReceived = 0
    
    while($jobsReceived -lt $jobs.Count) {
        if((Get-Date) -ge $timeout) {
            Write-Warning "Timed out waiting for all jobs to complete after $TimeoutMinutes minutes"
            break
        }
        $messages = Receive-SQSMessage -QueueUrl $sqsQueueUrl -MessageCount 10 -VisibilityTimeout 600
        if($messages) {
            foreach($message in $messages) {
                $jobsReceived++
                $body = ($message.Body | ConvertFrom-Json -Depth 25)
                if($body.deliveryError) {
                    Write-Host -ForegroundColor Red $body.deliveryError.errorMessage
                } elseif($body.responsePayload.errorMessage) {
                    Write-Host -ForegroundColor Red ($body.responsePayload | ConvertTo-Json -Depth 25)
                } else {
                    $key = [int]$body.responsePayload.Line
                    $start = [int]$body.responsePayload.Start
                    $terminalLine = [int][Math]::Floor($key/2)
                    $thisPixelGroupLinePosition = if($key % 2 -eq 0) { "Top" } else { "Bottom" }
                    $liveRenderResults[$terminalLine][$thisPixelGroupLinePosition][$start] = $body.responsePayload.Pixels
                    $existingPixelGroupLinePosition = if($key % 2 -eq 0) { "Bottom" } else { "Top" }
                    $existingPixelGroup = $liveRenderResults[$terminalLine][$existingPixelGroupLinePosition][$start]
                    [Console]::SetCursorPosition($canvasTopLeft.X + $start, $canvasTopLeft.Y + $terminalLine)
                    $thisPixelGroup = $liveRenderResults[$terminalLine][$thisPixelGroupLinePosition][$start]
                    for($p = 0; $p -lt $thisPixelGroup.Count; $p++) {
                        $existingPixel = @{ R = 25; G = 25; B = 25 }
                        if($existingPixelGroup) {
                            $existingPixel = $existingPixelGroup[$p]
                        }
                        $thisPixel = $thisPixelGroup[$p]
                        if($thisPixelGroupLinePosition -eq "Bottom") {
                            Write-Host -NoNewline "$([Char]27)[38;2;$($thisPixel.R);$($thisPixel.G);$($thisPixel.B)m$([Char]27)[48;2;$($existingPixel.R);$($existingPixel.G);$($existingPixel.B)m$([Char]0x2584)$([Char]27)[0m"
                        } else {
                            Write-Host -NoNewline "$([Char]27)[38;2;$($existingPixel.R);$($existingPixel.G);$($existingPixel.B)m$([Char]27)[48;2;$($thisPixel.R);$($thisPixel.G);$($thisPixel.B)m$([Char]0x2584)$([Char]27)[0m"
                        }
                    }
                    [Console]::SetCursorPosition($canvasTopLeft.X + $start, $canvasTopLeft.Y + $terminalLine)
                }
                $receipts += $message.ReceiptHandle
            }
            [Console]::SetCursorPosition($currentPosition.X, $currentPosition.Y)
            Write-Host -ForegroundColor DarkGray "$jobsReceived/$($Jobs.Count)    "
        }
    }
    [Console]::SetCursorPosition($endPosition.X, $endPosition.Y)
    [Console]::CursorVisible = $true

    return $receipts
}