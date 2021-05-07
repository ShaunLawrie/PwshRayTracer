# Pray to the Tray Racing Demi-Gods that this works
# 🙏 http://www.cs.otago.ac.nz/cosc342/ 🙏

$ErrorActionPreference = "Stop"

. "$PSScriptRoot/Classes.ps1"
Import-Module "$PSScriptRoot/ConsoleDrawing.psm1" -Force
Import-Module "$PSScriptRoot/ConsoleColors.psm1" -Force
Import-Module "$PSScriptRoot/RayVector.psm1" -Force
Import-Module "$PSScriptRoot/RayObject.psm1" -Force

function Invoke-RayTracer {
    $width = 25
    $height = 20
    $buffer = ""
    $objects = @(New-Sphere -X 10 -Y 5 -Z 0 -Radius 3)

    for($y = 0; $y -lt $height; $y++) {
        for($x = 0; $x -lt $width; $x++) {
            # This ray represents the path the light travels out through the eye through the pixel in the viewport
            $primaryRay = Get-PrimaryRay -X $x -Y $y

            # Compute intersections and find the nearest object the primary ray has hit
            $hit = $null
            $closestObject = $null
            $closestObjectDistance = [float]::MaxValue
            $objects | Foreach-Object {
                $hit = Get-SphereIntersection -Sphere $_ -Ray $primaryRay
                if ($hit) { 
                    $thisObjectDistance = Get-VectorDistance -PointA $eyePosition -PointB $hit #.Point
                    if ($thisObjectDistance -le $closestObjectDistance) { 
                        $closestObject = $_
                        $closestObjectDistance = $thisObjectDistance
                    }
                }
            }

            # compute illumination
            $closestObjectIsInShadow = $false
            if ($closestObject) {
                $shadowRay = Get-VectorSubtraction -Subtract $hit.Point -From $lightPosition
                $objects | Foreach-Object {
                    $shadowRayHitClosestObject = Get-SphereIntersection -Object $_ -Ray $shadowRay
                    if ($shadowRayHitClosestObject) { 
                        $closestObjectIsInShadow = $true
                        break
                    } 
                }
                if($closestObjectIsInShadow) {
                    # draw background
                    $buffer += Get-ColorBlock -R 0 -G 0 -B 0
                } else {
                    $litObject = [Rgb]@{
                        Red = $object.Color.Red * $light.Brightness
                        Green = $object.Color.Green * $light.Brightness
                        Blue = $object.Color.Blue * $light.Brightness
                    }
                    $buffer += Get-ColorBlock -R $litObject.Red -G $litObject.Green -B $litObject.Blue
                }
            } else {
                $buffer += Get-ColorBlock -R (10 + $y * 8) -G (10 + $x * 8) -B 200
            }
        }
        $buffer += "`n"
    }

    Write-HostBuffer -Buffer $buffer
}

Export-ModuleMember -Function "Invoke-RayTracer"