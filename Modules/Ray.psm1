$ErrorActionPreference = "Stop"
. "$PSScriptRoot/Classes.ps1"

function New-Ray {
    param(
        [System.Numerics.Vector3] $Origin,
        [System.Numerics.Vector3] $Direction
    )
    return [Ray]@{
        Origin = $Origin
        Direction = $Direction
    }
}

# https://raytracing.github.io/books/RayTracingInOneWeekend.html#rays,asimplecamera,andbackground/therayclass
function Get-RayPoint {
    param (
        [object] $Ray,
        [float] $T
    )
    $distance = $Ray.Direction * $T 
    $point = $Ray.Origin + $distance
    return $point
}

function Test-RayHitSphere {
    param (
        [object] $Ray,
        [float] $TMin,
        [float] $TMax,
        [object] $Sphere
    )

    $oc = $Ray.Origin - $Sphere.Center
    $a = $Ray.Direction.LengthSquared()
    $halfB = [System.Numerics.Vector3]::Dot($oc, $Ray.Direction)
    $c = $oc.LengthSquared() - ($Sphere.Radius * $Sphere.Radius)
    $discriminant = ($halfB * $halfB) - ($a * $c)

    if($discriminant -lt 0) {
        return $false
    }

    $sqrtd = [Math]::Sqrt($discriminant)

    $root = (-$halfB - $sqrtd) / $a;
    if ($root -lt $TMin -or $TMax -lt $root) {
        $root = (-$halfB + $sqrtd) / $a
        if ($root -lt $TMin -or $TMmax -lt $root) {
            return $false
        }
    }

    $hitPoint = Get-RayPoint -Ray $Ray -T $root
    $outwardNormal = ($hitPoint - $Sphere.Center) / $Sphere.Radius;

    # rec.set_face_normal(r, outward_normal);
    $frontFace = [System.Numerics.Vector3]::Dot($Ray.Direction, $outwardNormal) -lt 0
    $normal = if($frontFace) { $outwardNormal } else { -$outwardNormal }

    $hitRecord = [HitRecord]@{
        Point = $hitPoint
        Normal = $normal
        T = $root
        FrontFace = $frontFace
        Material = $Sphere.Material
    }

    return $hitRecord
}

function Get-RayClosestHit {
    param (
        [object] $Ray,
        [array] $Objects,
        [float] $TMin,
        [float] $TMax
    )
    $hitRecordForClosestObject = $null
    $closestSoFar = $TMax

    foreach($object in $Objects) {
        if($object -is [Sphere]) {
            $result = Test-RayHitSphere -Ray $Ray -Sphere $object -TMin $TMin -TMax $closestSoFar
            if($result) {
                $closestSoFar = $result.T
                $hitRecordForClosestObject = $result
            }
        }
    }

    return $hitRecordForClosestObject
}

function Get-RayClosestHitInlined {
    param (
        [object] $Ray,
        [array] $Objects,
        [float] $TMin,
        [float] $TMax
    )
    $hitRecordForClosestObject = $null
    $closestSoFar = $TMax

    foreach($object in $Objects) {
        if($object -is [Sphere]) {
            # INLINED: $result = Test-RayHitSphere -Ray $Ray -Sphere $object -TMin $TMin -TMax $closestSoFar
            $oc = $Ray.Origin - $object.Center
            $a = $Ray.Direction.LengthSquared()
            $halfB = [System.Numerics.Vector3]::Dot($oc, $Ray.Direction)
            $c = $oc.LengthSquared() - ($object.Radius * $object.Radius)
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

            # INLINED: $hitPoint = Get-RayPoint -Ray $Ray -T $root
            $distance = $Ray.Direction * $root 
            $hitPoint = $Ray.Origin + $distance

            $outwardNormal = ($hitPoint - $object.Center) / $object.Radius;

            # rec.set_face_normal(r, outward_normal);
            $frontFace = [System.Numerics.Vector3]::Dot($Ray.Direction, $outwardNormal) -lt 0
            $normal = if($frontFace) { $outwardNormal } else { -$outwardNormal }

            $hitRecord = [HitRecord]@{
                Point = $hitPoint
                Normal = $normal
                T = $root
                FrontFace = $frontFace
                Material = $object.Material
            }
            
            $closestSoFar = $hitRecord.T
            $hitRecordForClosestObject = $hitRecord
        }
    }

    return $hitRecordForClosestObject
}

function Get-RayColor {
    param (
        [object] $Ray,
        [array] $Scene,
        [int] $Depth,
        [string] $Diffuse
    )

    if ($Depth -le 0) {
        return [Rgb]@{
            Red = 0
            Green = 0
            Blue = 0
        }
    }

    if($global:InlinedRayTracingEnabled -or $global:InlinedRayTracingEnabledParallel) {
        # INLINED: $hitRecord = Get-RayClosestHit -Ray $Ray -TMin 0.001 -TMax ([float]::PositiveInfinity) -Objects $Scene
        $TMin = 0.001
        $hitRecordForClosestObject = $null
        $closestSoFar = ([float]::PositiveInfinity)

        foreach($object in $Scene) {
            if($object -is [Sphere]) {
                # INLINED: $result = Test-RayHitSphere -Ray $Ray -Sphere $object -TMin $TMin -TMax $closestSoFar
                $oc = $Ray.Origin - $object.Center
                $a = $Ray.Direction.LengthSquared()
                $halfB = [System.Numerics.Vector3]::Dot($oc, $Ray.Direction)
                $c = $oc.LengthSquared() - ($object.Radius * $object.Radius)
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

                # INLINED: $hitPoint = Get-RayPoint -Ray $Ray -T $root
                $distance = $Ray.Direction * $root 
                $hitPoint = $Ray.Origin + $distance

                $outwardNormal = ($hitPoint - $object.Center) / $object.Radius;

                # rec.set_face_normal(r, outward_normal);
                $frontFace = [System.Numerics.Vector3]::Dot($Ray.Direction, $outwardNormal) -lt 0
                $normal = if($frontFace) { $outwardNormal } else { -$outwardNormal }

                $currentHitRecord = [HitRecord]@{
                    Point = $hitPoint
                    Normal = $normal
                    T = $root
                    FrontFace = $frontFace
                    Material = $object.Material
                }
                
                $closestSoFar = $currentHitRecord.T
                $hitRecordForClosestObject = $currentHitRecord
            }
        }

        $hitRecord = $hitRecordForClosestObject
    } else {
        $hitRecord = Get-RayClosestHit -Ray $Ray -TMin 0.001 -TMax ([float]::PositiveInfinity) -Objects $Scene
    }
    
    $result = [Rgb]@{
        Red = 0
        Green = 0
        Blue = 0
    }

    # Fallback to generated background
    if($hitRecord) {
        if($Diffuse -eq "scattered") {
            # Material simulation
            if($global:InlinedRayTracingEnabled -or $global:InlinedRayTracingEnabledParallel) {
                # INLINED: $scattered = Get-VectorScattered -Ray $Ray HitRecord $hitRecord
                $scattered = $null
                if($HitRecord.Material.Reflective) {
                    $directionUnit = [System.Numerics.Vector3]::Normalize($Ray.Direction)
                    # INLINED: $reflected = Get-VectorReflected -Vector $directionUnit -Normal $HitRecord.Normal
                    $reflected = $directionUnit - (2 * [System.Numerics.Vector3]::Dot($directionUnit, $HitRecord.Normal) * $HitRecord.Normal)
                    # INLINED: Get-VectorRandomInUnitSphere
                    while ($True) {
                        if($global:FastRandomEnabled -or $global:FastRandomEnabledParallel) {
                            $x = $global:Random.Next(100) / 100.0
                            $y = $global:Random.Next(100) / 100.0
                            $z = $global:Random.Next(100) / 100.0
                        } else {
                            $x = (Get-Random -Minimum 0 -Maximum 100) / 100.0
                            $y = (Get-Random -Minimum 0 -Maximum 100) / 100.0
                            $z = (Get-Random -Minimum 0 -Maximum 100) / 100.0
                        }
                        $p = [System.Numerics.Vector3]::new($x, $y, $z)
                        if($p.LengthSquared() -ge 1) {
                            continue
                        }
                        $randomVectorInUnitSphere = $p
                        break
                    }
                    $fuzzedReflected = $reflected + ($HitRecord.Material.Fuzz * $randomVectorInUnitSphere)
                    # INLINED: $scatteredDirection = New-Ray -Origin $HitRecord.Point -Direction $fuzzedReflected
                    $scatteredDirection = [Ray]@{
                        Origin = $HitRecord.Point
                        Direction = $fuzzedReflected
                    }
                    if([System.Numerics.Vector3]::Dot($scatteredDirection.Direction, $HitRecord.Normal) -le 0) {
                        $scattered = $null
                    } else {
                        $scattered = @{
                            Direction = $scatteredDirection
                            Attenuation = @{
                                Red = $HitRecord.Material.Rgb.Red / 255.0
                                Green = $HitRecord.Material.Rgb.Green / 255.0
                                Blue = $HitRecord.Material.Rgb.Blue / 255.0
                            }
                        }
                    }
                } elseif($HitRecord.Material.Refractive) {
                    $refractionRatio = if($HitRecord.FrontFace) { 1.0 / $HitRecord.Material.RefractiveIndex } else { $HitRecord.Material.RefractiveIndex }
                    $directionUnit = [System.Numerics.Vector3]::Normalize($Ray.Direction)

                    $cosTheta = [Math]::Min([System.Numerics.Vector3]::Dot(-$directionUnit, $HitRecord.Normal), 1.0)
                    $sinTheta = [Math]::Sqrt(1.0 - ($cosTheta * $cosTheta))

                    $cannotRefract = $refractionRatio * $sinTheta -gt 1.0

                    $direction = $null
                    if($global:FastRandomEnabled -or $global:FastRandomEnabledParallel) {
                        $randomProb = $global:Random.Next(100) / 100.0
                    } else {
                        $randomProb = (Get-Random -Minimum 0 -Maximum 100) / 100.0
                    }
                    # INLINED: Get-VectorReflectance -CosineTheta $cosTheta -RefractionRatio $refractionRatio
                    $rZero = (1-$refractionRatio) / (1+$refractionRatio)
                    $rZeroSquared = $rZero * $rZero
                    $reflectance = $rZeroSquared + (1-$rZeroSquared)*[Math]::Pow((1 - $cosTheta), 5)
                    if($cannotRefract -or $reflectance -gt $randomProb) {
                        # INLINED: $direction = Get-VectorReflected -Vector $directionUnit -Normal $HitRecord.Normal
                        $direction = $directionUnit - (2 * [System.Numerics.Vector3]::Dot($directionUnit, $HitRecord.Normal) * $HitRecord.Normal)
                    } else {
                        #INLINED: $direction = Get-VectorRefracted -Vector $directionUnit -Normal $HitRecord.Normal -RefractionRatio $refractionRatio
                        $dotProduct = [System.Numerics.Vector3]::Dot(-$directionUnit, $HitRecord.Normal)
                        $cosTheta = [Math]::Min($dotProduct, 1.0)
                        $perpendicularRay = $refractionRatio * ($directionUnit + ($cosTheta * $HitRecord.Normal))
                        $parallelRay = -[Math]::Sqrt([Math]::Abs(1.0 - $perpendicularRay.LengthSquared())) * $HitRecord.Normal
                        $direction = $perpendicularRay + $parallelRay
                    }

                    $scattered = @{
                        # INLINED: New-Ray -Origin $HitRecord.Point -Direction $direction
                        Direction = [Ray]@{
                            Origin = $HitRecord.Point
                            Direction = $direction
                        }
                        Attenuation = @{
                            Red = 1.0
                            Green = 1.0
                            Blue = 1.0
                        }
                    }
                } else {
                    # INLINED: Get-VectorRandomUnit
                    while ($True) {
                        if($global:FastRandomEnabled -or $global:FastRandomEnabledParallel) {
                            $x = $global:Random.Next(100) / 100.0
                            $y = $global:Random.Next(100) / 100.0
                            $z = $global:Random.Next(100) / 100.0
                        } else {
                            $x = (Get-Random -Minimum 0 -Maximum 100) / 100.0
                            $y = (Get-Random -Minimum 0 -Maximum 100) / 100.0
                            $z = (Get-Random -Minimum 0 -Maximum 100) / 100.0
                        }
                        $p = [System.Numerics.Vector3]::new($x, $y, $z)
                        if($p.LengthSquared() -ge 1) {
                            continue
                        }
                        $randomInUnitSphere = $p
                        break
                    }
                    $randomUnit = [System.Numerics.Vector3]::Normalize($randomInUnitSphere)
                    $scatterDirection = $HitRecord.Normal + $randomUnit
                    # INLINED: Test-VectorNearZero -Vector $scatterDirection
                    $nearZero = 1e-8
                    $vectorNearZero = [Math]::Abs($scatterDirection.X) -lt $nearZero -and [Math]::Abs($scatterDirection.Y) -lt $nearZero -and [Math]::Abs($scatterDirection.Z) -lt $nearZero
                    if($vectorNearZero) {
                        $scatterDirection = $HitRecord.Normal
                    }
                    $scattered = @{
                        # INLINED: New-Ray -Origin $HitRecord.Point -Direction $scatterDirection
                        Direction = [Ray]@{
                            Origin = $HitRecord.Point
                            Direction = $scatterDirection
                        }
                        Attenuation = @{
                            Red = $HitRecord.Material.Rgb.Red / 255.0
                            Green = $HitRecord.Material.Rgb.Green / 255.0
                            Blue = $HitRecord.Material.Rgb.Blue / 255.0
                        }
                    }
                }
            } else {
                $scattered = Get-VectorScattered -Ray $Ray -HitRecord $hitRecord
            }
            if($scattered) {
                # Can't inline recursive function call
                $color = Get-RayColor -Ray $scattered.Direction -Scene $Scene -Depth ($Depth - 1) -Diffuse $Diffuse
                $result = [Rgb]@{
                    Red = [Math]::Min($scattered.Attenuation.Red * $color.Red, 255)
                    Green = [Math]::Min($scattered.Attenuation.Green * $color.Green, 255)
                    Blue = [Math]::Min($scattered.Attenuation.Blue * $color.Blue, 255)
                }
            }
        } else {
            # Simple tracing
            $diffuseDirection = switch($Diffuse) {
                "simple" { Get-VectorRandomInUnitSphere }
                "lambertian" { Get-VectorRandomUnit }
                "hemispherical" { Get-VectorRandomInHemisphere -Normal $hitRecord.Normal }
                default { throw "Unknown diffuse type '$Diffuse'" }
            }

            $target = $hitRecord.Point + $hitRecord.Normal + $diffuseDirection
            $reflectedRay = New-Ray -Origin $hitRecord.Point -Direction ($target - $hitRecord.Point)
            $color = Get-RayColor -Ray $reflectedRay -Scene $Scene -Depth ($Depth - 1) -Diffuse $Diffuse
            $result = [Rgb]@{
                Red = [Math]::Min(0.5 * ($color.Red), 255)
                Green = [Math]::Min(0.5 * ($color.Green), 255)
                Blue = [Math]::Min(0.5 * ($color.Blue), 255)
            }
        }
    } else {
        $unitDirection = [System.Numerics.Vector3]::Normalize($Ray.Direction)
        $t = 0.5 * ($unitDirection.Y + 1.0)
        $start = [Rgb]@{
            Red = 255 * (1.0 - $t)
            Green = 255 * (1.0 - $t)
            Blue = 255 * (1.0 - $t)
        }
        $end = [Rgb]@{
            Red = 127 * $t
            Green = 178 * $t
            Blue = 255 * $t
        }
        $result = [Rgb]@{
            Red = [Math]::Min($start.Red + $end.Red, 255)
            Green = [Math]::Min($start.Green + $end.Green, 255)
            Blue = [Math]::Min($start.Blue + $end.Blue, 255)
        }
    }
    return $result
}

Export-ModuleMember -Function "*-*"