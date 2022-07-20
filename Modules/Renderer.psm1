$ErrorActionPreference = "Stop"
. "$PSScriptRoot/Classes.ps1"

Import-Module "$PSScriptRoot/Console.psm1" -Force
Import-Module "$PSScriptRoot/Math.psm1" -Force
Import-Module "$PSScriptRoot/Vector.psm1" -Force

$global:FastRandomEnabled = $false
$global:InlinedRayTracingEnabled = $false
$global:Random = New-Object -TypeName System.Random

function Invoke-Renderer {
    param (
        [int] $ImageWidth = 136,
        # simple, lambertian, or hemispherical
        [string] $Diffuse = "lambertian",
        [int] $LeftPadding = 0,
        [object] $Scene,
        [int] $SamplesPerPixel = 15,
        [int] $SampleFuzziness = 100,
        [int] $MaxRayRecursionDepth = 10,
        [float] $FieldOfView = 90.0,
        [object] $LookFrom = [System.Numerics.Vector3]::new(0, 0, 0),
        [object] $LookAt = [System.Numerics.Vector3]::new(0, 0, -1),
        [object] $CameraUp = [System.Numerics.Vector3]::new(0, 1, 0),
        [float] $Aperture = 1.0,
        [float] $FocusDistance = ($LookFrom - $LookAt).Length(),
        # performance options
        [bool] $Progressive = $true,
        [bool] $FastRandom = $false,
        [bool] $InlinedRayTracing = $false,
        [bool] $Parallel = $false,
        [string] $Note
    )
    
    $global:FastRandomEnabled = $FastRandom
    $global:InlinedRayTracingEnabled = $InlinedRayTracing

    # Image
    $aspectWidth = 16.0
    $aspectHeight = 9.0
    $aspectRatio = $aspectWidth / $aspectHeight
    $imageHeight = [int]($ImageWidth / $aspectRatio)

    if($ImageWidth -ge ([Console]::WindowWidth / 2) -or $imageHeight -ge ([Console]::WindowHeight - 2)) {
        throw "Image width or $ImageWidth is trying to render wider or taller than the terminal window, try zooming out"
    }

    Initialize-Camera -AspectRatio $aspectRatio -FieldOfView $FieldOfView -LookFrom $LookFrom -LookAt $LookAt -CameraUp $CameraUp -Aperture $Aperture -FocusDistance $FocusDistance

    # Left terminal padding
    $leftPadding = [int](([Console]::WindowWidth / 2) - $ImageWidth)
    $title = " Powershell Ray Tracer 0.1a"
    $titleLength = $title.Length

    [Console]::SetCursorPosition($LeftPadding, 0)
    Write-Host $title
    $pixels = @{}
    $buffer = @{
        0 = New-Object -TypeName "System.Text.StringBuilder" -ArgumentList ([int]((($ImageWidth * $imageHeight) + $imageHeight) / 2))
        1 = New-Object -TypeName "System.Text.StringBuilder" -ArgumentList ([int]((($ImageWidth * $imageHeight) + $imageHeight) / 2))
    }
    if($Parallel) {
        $previousProgressPreference = $ProgressPreference
        $ProgressPreference = "SilentlyContinue"
        $info = Get-ComputerInfo
        $ProgressPreference = $previousProgressPreference
        $threads = $info.CsProcessors.NumberOfLogicalProcessors + 2
        $streams = [System.Collections.ArrayList]::new()
        $buffer = @{}
        $syncBuffer = [System.Collections.Hashtable]::Synchronized($buffer)
        $linesPerThread = [int]($imageHeight / $threads)
        for($i = 0; $i -lt $threads; $i++) {
            $buffer[$i] = New-Object -TypeName "System.Text.StringBuilder" -ArgumentList ([int]((($ImageWidth * $imageHeight) + $imageHeight) / 2))
            $streams.Add(
                @{
                    Index = $i
                    StartLine = ($i * $linesPerThread)
                    EndLine = (($i + 1) * $linesPerThread)
                }
            ) | Out-Null
        }
        $scriptRoot = $PSScriptRoot
        $parallelTiming = $streams | Foreach-Object -ThrottleLimit $threads -Parallel {
            $global:FastRandomEnabledParallel = $using:FastRandom
            $global:InlinedRayTracingEnabledParallel = $using:InlinedRayTracingEnabled

            . "$using:scriptRoot/Classes.ps1"

            Get-ChildItem -Path "$using:scriptRoot" -Filter "*.psm1" | Foreach-Object { Import-Module $_.PsPath -Force }

            Initialize-Camera -AspectRatio $using:aspectRatio -FieldOfView $using:FieldOfView -LookFrom $using:LookFrom -LookAt $using:LookAt -CameraUp $using:CameraUp -Aperture $using:Aperture -FocusDistance $using:FocusDistance

            $localRandom = New-Object -TypeName System.Random
            $localSyncBuffer = $using:syncBuffer
            $localPixels = @{}
            
            $rayTiming = Measure-Command {
                for ($sample = 0; $sample -lt $using:SamplesPerPixel; $sample++) {
                    for ($j = ($using:imageHeight - $_.StartLine); $j -ge ($using:imageHeight - $_.EndLine); $j = $j - 1) {
                        for ($i = 0; $i -le $using:ImageWidth; $i++) {
                            if(-not $localPixels.ContainsKey("$j.$i")) {
                                $localPixels["$j.$i"] = @{
                                    Rgb = [Rgb]@{
                                        Red = 0
                                        Green = 0
                                        Blue = 0
                                    }
                                    Samples = 1
                                }
                            }

                            $u = ($i + ($localRandom.Next($using:SampleFuzziness) / 100.0)) / ($using:ImageWidth - 1.0)
                            $v = ($j + ($localRandom.Next($using:SampleFuzziness) / 100.0)) / ($using:imageHeight - 1.0)
                            
                            $r = Get-CameraRay -S $u -T $v
                            $newColor = Get-RayColor -Ray $r -Scene $using:Scene -Depth $using:MaxRayRecursionDepth -Diffuse $using:Diffuse
                            $localPixels["$j.$i"] = @{
                                Rgb = [Rgb]@{
                                    Red = $localPixels["$j.$i"].Rgb.Red + $newColor.Red
                                    Green = $localPixels["$j.$i"].Rgb.Green + $newColor.Green
                                    Blue = $localPixels["$j.$i"].Rgb.Blue + $newColor.Blue
                                }
                                Samples = $sample + 1
                            }

                            if($sample -eq ($using:SamplesPerPixel - 1)) {
                                $pixelColor = [Rgb]@{
                                    Red = [Math]::Max([Math]::Min($localPixels["$j.$i"].Rgb.Red / $localPixels["$j.$i"].Samples, 255), 0)
                                    Green = [Math]::Max([Math]::Min($localPixels["$j.$i"].Rgb.Green / $localPixels["$j.$i"].Samples, 255), 0)
                                    Blue = [Math]::Max([Math]::Min($localPixels["$j.$i"].Rgb.Blue / $localPixels["$j.$i"].Samples, 255), 0)
                                }
                                $null = $localSyncBuffer[$_.Index].Append((Get-ColorBlock -Rgb $pixelColor))
                            }
                        }
                        if($sample -eq ($using:SamplesPerPixel - 1)) {
                            $null = $localSyncBuffer[$_.Index].AppendLine()
                        }
                    }
                }
            }
            return $rayTiming
        }
        $rayTiming = @{
            TotalMilliseconds = ($parallelTiming | Measure-Object -Min -Property TotalMilliseconds).Minimum
            TotalSeconds = ($parallelTiming | Measure-Object -Min -Property TotalSeconds).Minimum
        }
    } else {
        $rayTiming = Measure-Command {
            for ($sample = 0; $sample -lt $SamplesPerPixel; $sample++) {
                # Sampling incrementally adds to the pixel colors so the rough image is drawn fast and is refined with each sampling pass

                for ($scan = 0; $scan -lt 2; $scan++) {
                    if($progressive) {
                        [Console]::SetCursorPosition($LeftPadding, $scan)
                    }
                    # Progressive scan builds up even rows then odd

                    for ($j = ($imageHeight - $scan); $j -ge 0; $j = $j - 2) {
                        if($progressive) {
                            Write-ScanProgress -TitleLength $titleLength -Sample $sample -MaxSamples $SamplesPerPixel -Scan $scan -Line ($imageHeight - $j) -ImageHeight $ImageHeight -LeftPadding $LeftPadding
                            $currentCursorPosition = $Host.UI.RawUI.CursorPosition
                            [Console]::SetCursorPosition($LeftPadding, $currentCursorPosition.Y + 1)
                            Write-Host -NoNewline $(">")
                        }

                        for ($i = 0; $i -le $ImageWidth; $i++) {
                            if(-not $pixels.ContainsKey("$j.$i")) {
                                $pixels["$j.$i"] = @{
                                    Rgb = [Rgb]@{
                                        Red = 0
                                        Green = 0
                                        Blue = 0
                                    }
                                    Samples = 1
                                }
                            }

                            if($global:FastRandomEnabled -or $global:FastRandomEnabledParallel) {
                                $u = ($i + ($global:Random.Next($SampleFuzziness) / 100.0)) / ($ImageWidth - 1.0)
                                $v = ($j + ($global:Random.Next($SampleFuzziness) / 100.0)) / ($imageHeight - 1.0)
                            } else {
                                $u = ($i + ((Get-Random -Minimum 0 -Maximum $SampleFuzziness) / 100.0)) / ($ImageWidth - 1.0)
                                $v = ($j + ((Get-Random -Minimum 0 -Maximum $SampleFuzziness) / 100.0)) / ($imageHeight - 1.0)
                            }
                            $r = Get-CameraRay -S $u -T $v
                            $newColor = Get-RayColor -Ray $r -Scene $Scene -Depth $MaxRayRecursionDepth -Diffuse $Diffuse
                            $pixels["$j.$i"] = @{
                                Rgb = [Rgb]@{
                                    Red = $pixels["$j.$i"].Rgb.Red + $newColor.Red
                                    Green = $pixels["$j.$i"].Rgb.Green + $newColor.Green
                                    Blue = $pixels["$j.$i"].Rgb.Blue + $newColor.Blue
                                }
                                Samples = $sample + 1
                            }

                            if($progressive) {
                                $pixelColor = [Rgb]@{
                                    Red = [Math]::Max([Math]::Min($pixels["$j.$i"].Rgb.Red / $pixels["$j.$i"].Samples, 255), 0)
                                    Green = [Math]::Max([Math]::Min($pixels["$j.$i"].Rgb.Green / $pixels["$j.$i"].Samples, 255), 0)
                                    Blue = [Math]::Max([Math]::Min($pixels["$j.$i"].Rgb.Blue / $pixels["$j.$i"].Samples, 255), 0)
                                }
                                Write-Host -NoNewline (Get-ColorBlock -Rgb $pixelColor)
                            } else {
                                if($sample -eq ($SamplesPerPixel - 1)) {
                                    $pixelColor = [Rgb]@{
                                        Red = [Math]::Max([Math]::Min($pixels["$j.$i"].Rgb.Red / $pixels["$j.$i"].Samples, 255), 0)
                                        Green = [Math]::Max([Math]::Min($pixels["$j.$i"].Rgb.Green / $pixels["$j.$i"].Samples, 255), 0)
                                        Blue = [Math]::Max([Math]::Min($pixels["$j.$i"].Rgb.Blue / $pixels["$j.$i"].Samples, 255), 0)
                                    }
                                    $null = $buffer[$scan].Append((Get-ColorBlock -Rgb $pixelColor))
                                }
                            }
                        }

                        if($progressive) {
                            [Console]::SetCursorPosition($LeftPadding, $currentCursorPosition.Y + 1)
                            Write-Host " "
                        } else {
                            if($sample -eq ($SamplesPerPixel - 1)) {
                                $null = $buffer[$scan].AppendLine()
                            }
                        }
                    }
                    Write-ScanProgress -TitleLength $titleLength -Sample $sample -MaxSamples $SamplesPerPixel -Scan $scan -Line ($imageHeight - $j) -ImageHeight $ImageHeight -LeftPadding $leftPadding
                }
            }
        }
    }

    if(!$progressive) {
        if($Parallel) {
            $keys = $buffer.Keys | Sort-Object { $_ }
            foreach($key in $keys) {
                $lines = $buffer[$key].ToString().Split("`n")
                foreach($line in $lines) {
                    if(![string]::IsNullOrWhiteSpace($line)) {
                        Write-Host "$(' ' * $leftPadding) $line"
                    }
                }
            }
        } else {
            $linesEven = $buffer[0].ToString().Split("`n")
            $linesOdd = $buffer[1].ToString().Split("`n")
            for($i = 0; $i -lt $linesEven.Count; $i++) {
                if(![string]::IsNullOrWhiteSpace($linesEven[$i])) {
                    Write-Host "$(' ' * $leftPadding) $($linesEven[$i])"
                    Write-Host "$(' ' * $leftPadding) $($linesOdd[$i])"
                }
            }
        }
    }

    $raysPerSecond = [Math]::Round(($ImageWidth * $imageHeight * $SamplesPerPixel) / $rayTiming.TotalSeconds, 1)
    $pixelsPerSecond = [Math]::Round(($ImageWidth * $imageHeight) / $rayTiming.TotalSeconds, 1)

    $stats = "[Aspect ratio = ${aspectWidth}:$aspectHeight, Image width = $ImageWidth, Antialiasing samples = $SamplesPerPixel, Sample fuzziness = $SampleFuzziness, Diffuse = $Diffuse, Max ray recursion = $MaxRayRecursionDepth, Rays traced/sec = $raysPerSecond, Pixels/sec = $pixelsPerSecond, Render = $($rayTiming.TotalMilliseconds)ms]            "
    $statsSplit = (Select-String ".{1,$($ImageWidth * 2)}(\s|$)" -Input $stats -AllMatches).Matches.Value

    foreach($stat in $statsSplit) {
        if($progressive) {
            $currentCursorPosition = $Host.UI.RawUI.CursorPosition
            [Console]::SetCursorPosition($LeftPadding, $currentCursorPosition.Y + 1)
            Write-Host -ForegroundColor DarkGray -NoNewline " $stat"
        } else {
            Write-Host -ForegroundColor DarkGray "$(' ' * $leftPadding) $stat"
        }
    }

    $stringAsStream = [System.IO.MemoryStream]::new()
    $writer = [System.IO.StreamWriter]::new($stringAsStream)
    $writer.write(($Scene | ConvertTo-Json -Depth 5))
    $writer.Flush()
    $stringAsStream.Position = 0
    $sceneHash = (Get-FileHash -InputStream $stringAsStream -Algorithm MD5).Hash
    if(Test-Path "$sceneHash.scene.txt") {
        Write-Verbose "Scene $sceneHash already dumped"
    } else {
        Set-Content -Path "$sceneHash.scene.txt" -Value ($Scene | ConvertTo-Json -Depth 5)
    }
    $statsOutput = @"
===========================================================
Note                 = $Note
Date                 = $(Get-Date)
Scene                = MD5 $sceneHash
Aspect ratio         = ${aspectWidth}:$aspectHeight
Look From            = $LookFrom
Look At              = $LookAt
Image width          = $ImageWidth
Antialiasing samples = $SamplesPerPixel
Sample fuzziness     = $SampleFuzziness
Diffuse              = $Diffuse
Max ray recursion    = $MaxRayRecursionDepth
Rays traced/sec      = $raysPerSecond
Pixels/sec           = $pixelsPerSecond
Render               = $($rayTiming.TotalMilliseconds)ms
"@
    Add-Content "benchmarks.txt" -Value $statsOutput
}