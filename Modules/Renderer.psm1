$ErrorActionPreference = "Stop"
. "$PSScriptRoot/Classes.ps1"

Import-Module "$PSScriptRoot/Console.psm1" -Force
Import-Module "$PSScriptRoot/Math.psm1" -Force
Import-Module "$PSScriptRoot/Vector.psm1" -Force

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
        [float] $FocusDistance = ($LookFrom - $LookAt).Length()
    )

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
    $rayTiming = Measure-Command {
        for ($sample = 0; $sample -lt $SamplesPerPixel; $sample++) {
            # Sampling incrementally adds to the pixel colors so the rough image is drawn fast and is refined with each sampling pass

            for ($scan = 0; $scan -lt 2; $scan++) {
                [Console]::SetCursorPosition($LeftPadding, $scan)
                # Progressive scan builds up even rows then odd

                for ($j = ($imageHeight - $scan); $j -ge 0; $j = $j - 2) {
                    Write-ScanProgress -TitleLength $titleLength -Sample $sample -MaxSamples $SamplesPerPixel -Scan $scan -Line ($imageHeight - $j) -ImageHeight $ImageHeight -LeftPadding $LeftPadding
                    $currentCursorPosition = $Host.UI.RawUI.CursorPosition
                    [Console]::SetCursorPosition($LeftPadding, $currentCursorPosition.Y + 1)
                    Write-Host -NoNewline $(">")

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

                        $u = ($i + ((Get-Random -Minimum 0 -Maximum $SampleFuzziness) / 100.0)) / ($ImageWidth - 1.0)
                        $v = ($j + ((Get-Random -Minimum 0 -Maximum $SampleFuzziness) / 100.0)) / ($imageHeight - 1.0)
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

                        $pixelColor = [Rgb]@{
                            Red = [Math]::Max([Math]::Min($pixels["$j.$i"].Rgb.Red / $pixels["$j.$i"].Samples, 255), 0)
                            Green = [Math]::Max([Math]::Min($pixels["$j.$i"].Rgb.Green / $pixels["$j.$i"].Samples, 255), 0)
                            Blue = [Math]::Max([Math]::Min($pixels["$j.$i"].Rgb.Blue / $pixels["$j.$i"].Samples, 255), 0)
                        }
                        Write-Host -NoNewline (Get-ColorBlock -Rgb $pixelColor)
                    }

                    [Console]::SetCursorPosition($LeftPadding, $currentCursorPosition.Y + 1)
                    Write-Host " "
                }
                Write-ScanProgress -TitleLength $titleLength -Sample $sample -MaxSamples $SamplesPerPixel -Scan $scan -Line ($imageHeight - $j) -ImageHeight $ImageHeight -LeftPadding $leftPadding
            }
        }
    }
    $raysPerSecond = [Math]::Round(($ImageWidth * $imageHeight * $SamplesPerPixel) / $rayTiming.TotalSeconds, 1)
    $pixelsPerSecond = [Math]::Round(($ImageWidth * $imageHeight) / $rayTiming.TotalSeconds, 1)

    $stats = "[Aspect ratio = ${aspectWidth}:$aspectHeight, Image width = $ImageWidth, Antialiasing samples = $SamplesPerPixel, Sample fuzziness = $SampleFuzziness, Diffuse = $Diffuse, Max ray recursion = $MaxRayRecursionDepth, Rays traced/sec = $raysPerSecond, Pixels/sec = $pixelsPerSecond, Render = $($rayTiming.TotalMilliseconds)ms]            "
    $statsSplit = (Select-String ".{1,$($ImageWidth * 2)}(\s|$)" -Input $stats -AllMatches).Matches.Value

    foreach($stat in $statsSplit) {
        $currentCursorPosition = $Host.UI.RawUI.CursorPosition
        [Console]::SetCursorPosition($LeftPadding, $currentCursorPosition.Y + 1)
        Write-Host -ForegroundColor DarkGray -NoNewline " $stat"
    }
}