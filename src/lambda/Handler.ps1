function Resolve-SceneData {
    param (
        [object] $Scene
    )
    # Easiest way to deep copy
    $copy = $Scene | ConvertTo-Json -Depth 25 | ConvertFrom-Json
    
    $copy.Camera.LookFrom = [System.Numerics.Vector3]::new($copy.Camera.LookFrom.X, $copy.Camera.LookFrom.Y, $copy.Camera.LookFrom.Z)
    $copy.Camera.LookAt = [System.Numerics.Vector3]::new($copy.Camera.LookAt.X, $copy.Camera.LookAt.Y, $copy.Camera.LookAt.Z)
    $copy.Camera.CameraUp = [System.Numerics.Vector3]::new($copy.Camera.CameraUp.X, $copy.Camera.CameraUp.Y, $copy.Camera.CameraUp.Z)

    foreach($object in $copy.Objects) {
        $object.Center = [System.Numerics.Vector3]::new($object.Center.X, $object.Center.Y, $object.Center.Z)
    }

    return $copy
}

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

    $scene = Resolve-SceneData -Scene $snsMessage.Scene
    
    $chunkSize = [Math]::Ceiling(($snsMessage.End - $snsMessage.Start) / $cores)
    $messages += "Chunk size is $chunkSize for $($snsMessage.Start) -> $($snsMessage.End)"
    $parallelResults = 1..$cores | ForEach-Object -ThrottleLimit $cores -Parallel {
        $script:Random = New-Object -TypeName System.Random
        function Invoke-RayTracer {
            param (
                [object] $Scene,
                [int] $Line,
                [int] $Start,
                [int] $End
            )
        
            # Setup Image
            $imageWidth = $Scene.Camera.ImageWidth
            $aspectWidth = $Scene.Camera.AspectRatio.Split(":")[0]
            $aspectHeight = $Scene.Camera.AspectRatio.Split(":")[1]
            $aspectRatio = $aspectWidth / $aspectHeight
            $imageHeight = [int]($imageWidth / $aspectRatio)
        
            # Setup Camera
            $theta = $Scene.Camera.FieldOfView * ([math]::PI / 180)
            $h = [Math]::Tan($theta / 2.0)
            $viewportHeight = 2.0 * $h
            $viewportWidth = $aspectRatio * $viewportHeight
            $cameraW = [System.Numerics.Vector3]::Normalize($Scene.Camera.LookFrom - $Scene.Camera.LookAt)
            $cameraU = [System.Numerics.Vector3]::Normalize([System.Numerics.Vector3]::Cross($Scene.Camera.CameraUp, $cameraW))
            $cameraV = [System.Numerics.Vector3]::Cross($cameraW, $cameraU)
            $cameraOrigin = $Scene.Camera.LookFrom
            $cameraHorizontal = $Scene.Camera.FocusDistance * $viewportWidth * $cameraU
            $cameraVertical = $Scene.Camera.FocusDistance * $viewportHeight * $cameraV
            $cameraLowerLeftCorner = $cameraOrigin - ($cameraHorizontal / 2.0) - ($cameraVertical / 2.0) - ($Scene.Camera.FocusDistance * $cameraW)
            $cameraLensRadius = $Scene.Camera.Aperture / 2.0
         
            # Trace
            $localPixels = [System.Collections.ArrayList]::new()
            
            $j = $imageHeight - $Line
            for ($i = $Start; $i -lt $End; $i++) {
                $currentPixel = @{
                    R = 0
                    G = 0
                    B = 0
                }
                for ($sample = 0; $sample -lt $Scene.Camera.SamplesPerPixel; $sample++) {
                    $u = ($i + ($script:Random.Next(100) / 100.0)) / ($imageWidth - 1.0)
                    $v = ($j + ($script:Random.Next(100) / 100.0)) / ($imageHeight - 1.0)
                    $rd = $null
                    while($null -eq $rd) {
                        $x = ($script:Random.Next(200) - 100) / 100.0
                        $y = ($script:Random.Next(200) - 100) / 100.0
                        $p = [System.Numerics.Vector3]::new($x, $y, 0)
                        if($p.LengthSquared() -ge 1) {
                            continue
                        }
                        $rd = $cameraLensRadius * $p
                    }
                    $offset = ($cameraU * $rd.X) + ($cameraV * $rd.Y)
        
                    $sampleColor = Get-RayColor -Scene $Scene.Objects -Point ($cameraOrigin + $offset) -Direction ($cameraLowerLeftCorner + ($u * $cameraHorizontal) + ($v * $cameraVertical) - $cameraOrigin - $offset) -Depth $Scene.Camera.MaxRayRecursionDepth
                    
                    $currentPixel.R += $sampleColor.R
                    $currentPixel.G += $sampleColor.G
                    $currentPixel.B += $sampleColor.B
                }
        
                $localPixels.Add(
                    @{
                        R = [Math]::Clamp($currentPixel.R / ($Scene.Camera.SamplesPerPixel - 1), 0, 255)
                        G = [Math]::Clamp($currentPixel.G / ($Scene.Camera.SamplesPerPixel - 1), 0, 255)
                        B = [Math]::Clamp($currentPixel.B / ($Scene.Camera.SamplesPerPixel - 1), 0, 255)
                    }
                ) | Out-Null
            }
            
            return $localPixels
        }

        function Get-RayColor {
            param (
                [object] $Scene,
                [System.Numerics.Vector3] $Point,
                [System.Numerics.Vector3] $Direction,
                [int] $Depth
            )
        
            $TMin = 0.001
        
            if ($Depth -le 0) {
                return @{
                    R = 0
                    G = 0
                    B = 0
                }
            }
        
            $hitRecord = $null
            $closestSoFar = ([float]::PositiveInfinity)
        
            $a = $Direction.LengthSquared()
            
            foreach($object in $Scene) {
                $oc = $Point - $object.Center
                $halfB = [System.Numerics.Vector3]::Dot($oc, $Direction)
                $c = $oc.LengthSquared() - $object.RadiusSquared
                $discriminant = ($halfB * $halfB) - ($a * $c)
        
                if($discriminant -lt 0) {
                    continue
                }
        
                $sqrtd = [Math]::Sqrt($discriminant)
        
                $root = (-$halfB - $sqrtd) / $a;
                if ($root -lt $TMin -or $closestSoFar -lt $root) {
                    $root = (-$halfB + $sqrtd) / $a
                    if ($root -lt $TMin -or $closestSoFar -lt $root) {
                        continue
                    }
                }
        
                $distance = $Direction * $root 
                $hitPoint = $Point + $distance
        
                $outwardNormal = ($hitPoint - $object.Center) / $object.Radius;
        
                $frontFace = [System.Numerics.Vector3]::Dot($Direction, $outwardNormal) -lt 0
                $normal = if($frontFace) { $outwardNormal } else { -$outwardNormal }
        
                $hitRecord = @{
                    HitPoint = $hitPoint
                    Normal = $normal
                    FrontFace = $frontFace
                    Material = $object.Material
                }
                
                $closestSoFar = $root
            }
            
            if($hitRecord) {
                $scatteredDirection = $null
                $scatteredAttenuationR = $null
                $scatteredAttenuationG = $null
                $scatteredAttenuationB = $null
                
                if($hitRecord.Material.Reflective) {
                    $directionUnit = [System.Numerics.Vector3]::Normalize($Direction)
                    $reflected = $directionUnit - (2 * [System.Numerics.Vector3]::Dot($directionUnit, $hitRecord.Normal) * $hitRecord.Normal)
                    while ($True) {
                        $x = $script:Random.Next(100) / 100.0
                        $y = $script:Random.Next(100) / 100.0
                        $z = $script:Random.Next(100) / 100.0
                        $p = [System.Numerics.Vector3]::new($x, $y, $z)
                        if($p.LengthSquared() -ge 1) {
                            continue
                        }
                        $randomVectorInUnitSphere = $p
                        break
                    }
                    $fuzzedReflected = $reflected + ($hitRecord.Material.Fuzz * $randomVectorInUnitSphere)
                    if([System.Numerics.Vector3]::Dot($hitRecord.HitPoint, $hitRecord.Normal) -gt 0) {
                        $hitRecordMaterialColor = $hitRecord.Material.Color
                        $scatteredDirection = $fuzzedReflected
                        $scatteredAttenuationR = $hitRecordMaterialColor.R / 255.0
                        $scatteredAttenuationG = $hitRecordMaterialColor.G / 255.0
                        $scatteredAttenuationB = $hitRecordMaterialColor.B / 255.0
                    } else {
                        return @{
                            R = 0
                            G = 0
                            B = 0
                        }
                    }
                } elseif($hitRecord.Material.Refractive) {
                    $refractionRatio = if($hitRecord.FrontFace) { 1.0 / $hitRecord.Material.RefractiveIndex } else { $hitRecord.Material.RefractiveIndex }
                    $directionUnit = [System.Numerics.Vector3]::Normalize($Direction)
        
                    $cosTheta = [Math]::Min([System.Numerics.Vector3]::Dot(-$directionUnit, $hitRecord.Normal), 1.0)
                    $sinTheta = [Math]::Sqrt(1.0 - ($cosTheta * $cosTheta))
        
                    $cannotRefract = $refractionRatio * $sinTheta -gt 1.0
        
                    $refractedDirection = $null
                    $randomProb = $script:Random.Next(100) / 100.0
                    $rZero = (1-$refractionRatio) / (1+$refractionRatio)
                    $rZeroSquared = $rZero * $rZero
                    $reflectance = $rZeroSquared + (1-$rZeroSquared)*[Math]::Pow((1 - $cosTheta), 5)
                    if($cannotRefract -or $reflectance -gt $randomProb) {
                        $refractedDirection = $directionUnit - (2 * [System.Numerics.Vector3]::Dot($directionUnit, $hitRecord.Normal) * $hitRecord.Normal)
                    } else {
                        $dotProduct = [System.Numerics.Vector3]::Dot(-$directionUnit, $hitRecord.Normal)
                        $cosTheta = [Math]::Min($dotProduct, 1.0)
                        $perpendicularRay = $refractionRatio * ($directionUnit + ($cosTheta * $hitRecord.Normal))
                        $parallelRay = -[Math]::Sqrt([Math]::Abs(1.0 - $perpendicularRay.LengthSquared())) * $hitRecord.Normal
                        $refractedDirection = $perpendicularRay + $parallelRay
                    }
        
                    $scatteredDirection = $refractedDirection
                    $scatteredAttenuationR = 1.0
                    $scatteredAttenuationG = 1.0
                    $scatteredAttenuationB = 1.0
                } else {
                    while ($True) {
                        $x = $script:Random.Next(100) / 100.0
                        $y = $script:Random.Next(100) / 100.0
                        $z = $script:Random.Next(100) / 100.0
                        $p = [System.Numerics.Vector3]::new($x, $y, $z)
                        if($p.LengthSquared() -ge 1) {
                            continue
                        }
                        $randomInUnitSphere = $p
                        break
                    }
                    $randomUnit = [System.Numerics.Vector3]::Normalize($randomInUnitSphere)
                    $scatterDirection = $hitRecord.Normal + $randomUnit
                    $nearZero = 1e-8
                    $vectorNearZero = [Math]::Abs($scatterDirection.X) -lt $nearZero -and [Math]::Abs($scatterDirection.Y) -lt $nearZero -and [Math]::Abs($scatterDirection.Z) -lt $nearZero
                    if($vectorNearZero) {
                        $scatterDirection = $hitRecord.Normal
                    }
        
                    $scatteredDirection = $scatterDirection
                    $hitRecordMaterialColor = $hitRecord.Material.Color
                    $scatteredAttenuationR = $hitRecordMaterialColor.R / 255.0
                    $scatteredAttenuationG = $hitRecordMaterialColor.G / 255.0
                    $scatteredAttenuationB = $hitRecordMaterialColor.B / 255.0
                }
                
                $color = Get-RayColor -Scene $Scene -Point $hitRecord.HitPoint -Direction $scatteredDirection -Depth ($Depth - 1)
                return @{
                    R = [Math]::Min($scatteredAttenuationR * $color.R, 255)
                    G = [Math]::Min($scatteredAttenuationG * $color.G, 255)
                    B = [Math]::Min($scatteredAttenuationB * $color.B, 255)
                }
            } else {
                $unitDirection = [System.Numerics.Vector3]::Normalize($Direction)
                $t = 0.5 * ($unitDirection.Y + 1.0)
                $startV = 255 * (1.0 - $t)
                $endR = 127 * $t
                $endG = 178 * $t
                $endB = 255 * $t
                return @{
                    R = [Math]::Min($startV + $endR, 255)
                    G = [Math]::Min($startV + $endG, 255)
                    B = [Math]::Min($startV + $endB, 255)
                }
            }
        }

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