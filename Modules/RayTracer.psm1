# Pray to the Tray Racing Demi-Gods that this works
# 🙏 http://www.cs.otago.ac.nz/cosc342/ 🙏

$ErrorActionPreference = "Stop"

. "$PSScriptRoot/Classes.ps1"
Import-Module "$PSScriptRoot/ConsoleDrawing.psm1" -Force
Import-Module "$PSScriptRoot/ConsoleColors.psm1" -Force
Import-Module "$PSScriptRoot/RayVector.psm1" -Force
Import-Module "$PSScriptRoot/RayObject.psm1" -Force

function Invoke-RayTracer {
    $global:ImageWidth = 25
    $global:ImageHeight = 20
    $buffer = ""
    $objects = @(New-Sphere -X 0 -Y 0 -Z 2 -Radius 1.0)
    $light = @{
        Brightness = 1.0
    }

    for($y = 0; $y -lt $global:ImageHeight; $y++) {
        for($x = 0; $x -lt $global:ImageWidth; $x++) {
            # This ray represents the path the light travels out through the eye through the pixel in the viewport
            $primaryRay = Get-PrimaryRay -PixelX $x -PixelY $y
            # Compute intersections and find the nearest object the primary ray has hit
            $hit = $null
            $closestObject = $null
            $closestObjectDistance = [float]::MaxValue

            foreach($object in $Objects) {
                $hit = Get-SphereIntersection -Sphere $object -Ray $primaryRay
                if ($hit) { 
                    $thisObjectDistance = Get-VectorDistance -PointA $eyePosition -PointB $hit #.Point
                    if ($thisObjectDistance -le $closestObjectDistance) { 
                        $closestObject = $object
                        $closestObjectDistance = $thisObjectDistance
                    }
                }
            }

            # compute illumination
            $closestObjectIsInShadow = $false
            if ($null -ne $closestObject) {
                <#
                $shadowRay = Get-VectorSubtraction -Subtract $hit.Point -From $lightPosition
                foreach($object in $objects) {
                    $shadowRayHitClosestObject = Get-SphereIntersection -Object $object -Ray $shadowRay
                    if ($shadowRayHitClosestObject) { 
                        $closestObjectIsInShadow = $true
                        break
                    } 
                }
                #>
                if($closestObjectIsInShadow) {
                    # draw background
                    $buffer += Get-ColorBlock -R 0 -G 0 -B 0
                } else {
                    $litObject = [Rgb]@{
                        Red = $closestObject.Rgb.Red * $light.Brightness
                        Green = $closestObject.Rgb.Green * $light.Brightness
                        Blue = $closestObject.Rgb.Blue * $light.Brightness
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