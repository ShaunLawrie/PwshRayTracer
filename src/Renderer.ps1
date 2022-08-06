function Invoke-Handler {
    param (
        [object] $LambdaInput,
        [object] $LambdaContext
    )

    $messages = @()
    $cores = 1
    try {
        $cores = Invoke-Expression "nproc"
        $messages += "Found $cores CPU cores"
    } catch {
        $messages += "Failed to get number of CPUs $_"
    }

    $parallelResults = 1..$cores | ForEach-Object -ThrottleLimit $cores -Parallel {
        $pixels = @()
        for($i = 0; $i -lt 5; $i++) {
            $pixels += @{
                R = (Get-Random -Maximum 255)
                G = (Get-Random -Maximum 255)
                B = (Get-Random -Maximum 255)
            }
        }
        return $pixels
    }
    
    $response = @{
        Line = 0
        Pixels = $parallelResults
        Message = ($messages -join "`n")
    }

    Write-Output ($response | ConvertTo-Json -Depth 5)
}