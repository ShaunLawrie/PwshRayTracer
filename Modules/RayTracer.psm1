# Pray to the Tray Racing Demi-Gods that this works
# 🙏 http://www.cs.otago.ac.nz/cosc342/ 🙏

$ErrorActionPreference = "Stop"

. "$PSScriptRoot/Classes.ps1"
Import-Module "$PSScriptRoot/ConsoleDrawing.psm1" -Force
Import-Module "$PSScriptRoot/ConsoleColors.psm1" -Force
Import-Module "$PSScriptRoot/RayVector.psm1" -Force
Import-Module "$PSScriptRoot/RayObject.psm1" -Force

function Invoke-RayTracer {
    param (
        [int] $Frame = 0
    )
    $global:ImageWidth = ([Console]::WindowWidth / 2) - 1
    $global:ImageHeight = [Console]::WindowHeight - 2
    $global:ShadowsEnabled = $false
    
    $buffer = " "
    0..($global:ImageWidth - 1) | Foreach-Object {
        $buffer += "$($_ % 10) "
    }
    $buffer += "`n"

    # Read scene from json
    $scene = Read-Scene -Scene (Get-Content -Path "$PSScriptRoot/../Scene.json" | ConvertFrom-Json)
    for($y = 0; $y -lt $global:ImageHeight; $y++) {
        $buffer += "$($y % 10)"
        for($x = 0; $x -lt $global:ImageWidth; $x++) {
            # This ray represents the path the light travels out through the eye through the pixel in the viewport
            $primaryRay = Get-PrimaryRay -PixelX $x -PixelY $y
            # Compute intersections and find the nearest object the primary ray has hit
            $pointHit = $null
            $pointHitNormal = $null
            $closestObject = $null
            $closestObjectDistance = [float]::MaxValue

            foreach($object in $scene.Objects) {
                $thisObjectPointHit = Get-SphereIntersection -Sphere $object -Ray $primaryRay
                if ($thisObjectPointHit) {
                    $thisObjectDistance = Get-VectorDistance -PointA $primaryRay.Origin -PointB $thisObjectPointHit
                    if ($thisObjectDistance -le $closestObjectDistance) { 
                        $pointHit = $thisObjectPointHit
                        # This is not handling being inside the sphere, if the normal and view direction are not facing opposite directions
                        # then this would be inside the sphere
                        $pointHitNormal = Get-NormalizedVector (Get-VectorSubtraction -Subtract $object.Origin -From $thisObjectPointHit)
                        $closestObject = $object
                        $closestObjectDistance = $thisObjectDistance
                    }
                }
            }

            if ($null -ne $closestObject) {
                # compute illumination
                $closestObjectIsInShadow = $false
                $shadowRay = @{
                    Origin = $pointHit
                    Direction = Get-NormalizedVector (Get-VectorSubtraction -Substract $pointHit -From $light.Center)
                }
                foreach($object in $scene.Objects) {
                    if($object -ne $closestObject) {
                        $shadowRayHitClosestObject = Get-SphereIntersection -Sphere $object -Ray $shadowRay
                        if ($shadowRayHitClosestObject) { 
                            $closestObjectIsInShadow = $true
                            break
                        }
                    }
                }
                
                if($closestObjectIsInShadow -and $global:ShadowsEnabled){
                    # draw background
                    $buffer += Get-ColorBlock -R 255 -G 0 -B 0
                } else {
                    $litObject = [Rgb]@{
                        Red = 0
                        Green = 0
                        Blue = 0
                    }
                    foreach($light in $scene.Lights) {
                        $transmission = 1
                        # set transmission based on if the light hits anything first
                        # e.g. foreach other object check for collision between light and this point
                        $lightDirection = Get-NormalizedVector (Get-VectorSubtraction -Subtract $pointHit -From $light)
                        $illumination = [Math]::Max((Get-VectorDotProduct -VectorA $pointHitNormal -VectorB $lightDirection), 0)
                        $litObject.Red += [Math]::Min($closestObject.Rgb.Red * $illumination * $transmission, 255)
                        $litObject.Green += [Math]::Min($closestObject.Rgb.Green * $illumination * $transmission, 255)
                        $litObject.Blue += [Math]::Min($closestObject.Rgb.Blue * $illumination * $transmission, 255)
                    }
                    
                    $buffer += Get-ColorBlock -R $litObject.Red -G $litObject.Green -B $litObject.Blue
                }
            } else {
                $buffer += Get-ColorBlock -R 41 -G 57 -B 143
                #$buffer += Get-ColorBlock -R (255 / $global:ImageHeight * $y) -G (255 / $global:ImageWidth * $x) -B 200
            }
        }
        $buffer += "`n"
    }

    Write-HostBuffer -Buffer $buffer
}

function Read-Scene {
    param (
        [object] $Scene
    )
    $sceneOutput = @{
        Objects = @()
        Lights = @()
    }
    foreach ($object in $Scene.Objects) {
        if($object.Type -ieq "Sphere") {
            $sceneOutput.Objects += , (New-Sphere -X $object.X -Y $object.Y -Z $object.Z `
                -Radius $object.Radius -Rgb (Get-Rgb -R $object.R -G $object.G -B $object.B))
        } else {
            Write-Warning "Only 'Sphere' objects are supported"
        }
    }
    foreach ($light in $Scene.Lights) {
        if($light.Type -ieq "Point") {
            $sceneOutput.Lights += , @{
                X = $light.X
                Y = $light.Y
                Z = $light.Z
            }
        } else {
            Write-Warning "Only 'Point' lights are supported"
        }
    }
    return $sceneOutput
}

Export-ModuleMember -Function "Invoke-RayTracer"