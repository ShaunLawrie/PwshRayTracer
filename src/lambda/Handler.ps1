function Invoke-Handler {
    param (
        [object] $LambdaInput,
        [object] $LambdaContext
    )

    $messages = @()

    try {
        $snsMessage = $LambdaInput.Records[0].Sns.Message | ConvertFrom-Json
        $messages += "Converted input message successfully"
    } catch {
        $messages += "Failed to get request payload from $($LambdaInput | ConvertTo-Json -Depth 25)"
    }

    $cores = 1
    try {
        $cores = Invoke-Expression "nproc"
        $messages += "Found $cores logical CPU cores"
    } catch {
        $messages += "Failed to get number of logical CPU cores $_"
    }

    Import-Module "$PSScriptRoot/modules/RayTracer.psm1"
    $scene = Resolve-SceneData -Scene $snsMessage.Scene
    
    $chunkSize = [Math]::Ceiling(($snsMessage.End - $snsMessage.Start) / $cores)
    $messages += "Chunk size is $chunkSize for $($snsMessage.Start) -> $($snsMessage.End)"
    $scriptRoot = $PSScriptRoot
    $parallelResults = 1..$cores | ForEach-Object -ThrottleLimit $cores -Parallel {
        Import-Module "$using:scriptRoot/modules/RayTracer.psm1"
        $offset = $_ - 1
        $localStart = $using:snsMessage.Start + ($offset * $using:chunkSize)
        $localEnd = [Math]::Min(($localStart + $using:chunkSize), $using:snsMessage.End)
        $localPixels = Invoke-RayTracer -Scene $using:scene -Line $using:snsMessage.Line -Start $localStart -End $localEnd
        return @{
            Start = $localStart
            End = $localEnd
            Pixels = $localPixels
        }
    }

    $messages += "Parallel results: $($parallelResults | ConvertTo-Json -Depth 25)"

    $response = @{
        Line = $snsMessage.Line
        Start = $snsMessage.Start
        Pixels = ($parallelResults | Sort-Object { $_.Start } | Select-Object -ExpandProperty "Pixels")
        Messages = $messages
    }

    Write-Output ($response | ConvertTo-Json -Depth 5)
}