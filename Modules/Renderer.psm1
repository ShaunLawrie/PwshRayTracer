$ErrorActionPreference = "Stop"
. "$PSScriptRoot/Classes.ps1"

Import-Module "$PSScriptRoot/Console.psm1" -Force
Import-Module "$PSScriptRoot/Math.psm1" -Force
Import-Module "$PSScriptRoot/Vector.psm1" -Force

function Invoke-Renderer {

    # 180 wide will take approximately 20 seconds
    # 300 wide will take approximately 95 seconds
    # 600 wide will take approximately 20 minutes

    # Image
    $aspectWidth = 16.0
    $aspectHeight = 9.0
    $aspectRatio = $aspectWidth / $aspectHeight
    $imageWidth = 90
    $imageHeight = [int]($imageWidth / $aspectRatio)
    $samplesPerPixel = 4
    $sampleFuzziness = 10

    if($imageWidth -ge ([Console]::WindowWidth / 2) -or $imageHeight -ge ([Console]::WindowHeight - 2)) {
        throw "Image width or $imageWidth is trying to render wider or taller than the terminal window, try zooming out"
    }

    Initialize-Camera -AspectRatio $aspectRatio

    # The scene description
    $scene = @(
        # center screen sphere
        [Sphere]@{
            Center = [System.Numerics.Vector3]::new(0, 0, -1)
            Radius = 0.5
            Rgb = [Rgb]@{Red = 255; Green = 0; Blue = 0}
        },
        # ground sphere
        [Sphere]@{
            Center = [System.Numerics.Vector3]::new(0, -100.5, -1)
            Radius = 100.0
            Rgb = [Rgb]@{Red = 0; Green = 255; Blue = 0}
        }
    )

    # Left terminal padding
    $leftPadding = (([Console]::WindowWidth / 2) - $imageWidth)

    $buffer = "$(" " * $leftPadding)Powershell Ray Tracer 0.1a`n"

    $rayTiming = Measure-Command {
        for ($j = $imageHeight; $j -ge 0; --$j) {
            Write-Progress -Activity "Rendering" -PercentComplete ((($imageHeight - $j) / $imageHeight) * 100.0) -Status "Line $($imageHeight - $j)"
            
            $buffer += " " * $leftPadding

            for ($i = 0; $i -le $imageWidth; ++$i) {
                $color = [Rgb]@{
                    Red = 0
                    Green = 0
                    Blue = 0
                }

                for ($s = 0; $s -lt $samplesPerPixel; ++$s) {
                    $u = ($i + ((Get-Random -Minimum 0 -Maximum $sampleFuzziness) / 100.0)) / ($imageWidth - 1.0)
                    $v = ($j + ((Get-Random -Minimum 0 -Maximum $sampleFuzziness) / 100.0)) / ($imageHeight - 1.0)
                    $r = Get-CameraRay -U $u -V $v
                    $newColor = Get-RayColor -Ray $r -Scene $scene
                    $color = [Rgb]@{
                        Red = $color.Red + $newColor.Red
                        Green = $color.Green + $newColor.Green
                        Blue = $color.Blue + $newColor.Blue
                    }
                }

                $color = [Rgb]@{
                    Red = [Math]::Max([Math]::Min($color.Red / $samplesPerPixel, 255), 0)
                    Green = [Math]::Max([Math]::Min($color.Green / $samplesPerPixel, 255), 0)
                    Blue = [Math]::Max([Math]::Min($color.Blue / $samplesPerPixel, 255), 0)
                }

                $buffer += Get-ColorBlock -Rgb $color
            }

            $buffer += "`n"
        }
        Write-Progress -Activity "Rendering" -Completed
    }
    $renderTiming = Measure-Command {
        Write-HostBuffer -Buffer $buffer
    }
    Write-Host -ForegroundColor DarkGray "$(" " * $leftPadding)[Aspect ratio = ${aspectWidth}:$aspectHeight, Image width = $imageWidth, Antialiasing samples = $samplesPerPixel, Ray tracing = $($rayTiming.TotalMilliseconds)ms, Render = $($renderTiming.TotalMilliseconds)ms]            "
}