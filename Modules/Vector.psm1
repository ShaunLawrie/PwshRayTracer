$ErrorActionPreference = "Stop"
. "$PSScriptRoot/Classes.ps1"

function New-Vector3 {
    param(
        [float] $X,
        [float] $Y,
        [float] $Z
    )
    return [Vec3]@{
        X = $X
        Y = $Y
        Z = $Z
    }
}

function Get-VectorSubtraction {
    param(
        [object] $Subtract,
        [object] $From
    )
    return [vec3]@{
        X = $From.X - $Subtract.X
        Y = $From.Y - $Subtract.Y
        Z = $From.Z - $Subtract.Z
    }
}

function Get-VectorAddition {
    param(
        [object] $Add,
        [object] $To
    )
    return [vec3]@{
        X = $To.X + $Add.X
        Y = $To.Y + $Add.Y
        Z = $To.Z + $Add.Z
    }
}

function Get-VectorMultiple {
    param(
        [object] $VectorA,
        [object] $VectorB
    )
    return [vec3]@{
        X = $VectorA.X * $VectorB.X
        Y = $VectorA.Y * $VectorB.Y
        Z = $VectorA.Z * $VectorB.Z
    }
}

function Get-VectorScalarMultiple {
    param(
        [object] $Vector,
        [float] $Multiplier
    )
    return [vec3]@{
        X = $Vector.X * $Multiplier
        Y = $Vector.Y * $Multiplier
        Z = $Vector.Z * $Multiplier
    }
}

function Get-VectorScalarDivision {
    param(
        [object] $Vector,
        [float] $Divisor
    )
    return [vec3]@{
        X = $Vector.X / $Divisor
        Y = $Vector.Y / $Divisor
        Z = $Vector.Z / $Divisor
    }
}

# https://www.calculatorsoup.com/calculators/geometry-solids/distance-two-points.php
function Get-VectorDistance {
    param(
        [object] $PointA,
        [object] $PointB
    )
    return [Math]::Sqrt(
        [Math]::Pow($PointA.X - $PointB.X, 2) +
        [Math]::Pow($PointA.Y - $PointB.Y, 2) +
        [Math]::Pow($PointA.Z - $PointB.Z, 2)
    )
}

# https://www.cuemath.com/calculus/unit-vector/
function Get-VectorUnit {
    param(
        [object] $Vector
    )
    $length = Get-VectorLength -Vector $Vector
    return [vec3]@{
        X = $Vector.X / $length
        Y = $Vector.Y / $length
        Z = $Vector.Z / $length
    }
}

# https://www.storyofmathematics.com/length-of-a-vector/
function Get-VectorLength {
    param(
        [object] $Vector
    )
    return (
        [math]::Sqrt(
            ($Vector.X * $Vector.X) +
            ($Vector.Y * $Vector.Y) + 
            ($Vector.Z * $Vector.Z)
        )
    )
}

# https://www.mathsisfun.com/algebra/vectors-dot-product.html
function Get-VectorDotProduct {
    param(
        [object] $VectorA,
        [object] $VectorB
    )
    return (
        $VectorA.X * $VectorB.X +
        $VectorA.Y * $VectorB.Y + 
        $VectorA.Z * $VectorB.Z
    )
}

# https://www.mathsisfun.com/algebra/vectors-cross-product.html
function Get-VectorCrossProduct {
    param(
        [object] $VectorA,
        [object] $VectorB
    )
    return [vec3]@{
        X = $VectorA.Y * $VectorB.Z - $VectorA.Z * $VectorB.Y
        Y = $VectorA.Z * $VectorB.X - $VectorA.X * $VectorB.Z
        Z = $VectorA.X * $VectorB.Y - $VectorA.Y * $VectorB.X
    }
}

function Get-VectorRandomInUnitSphere {
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
        return $p
    }
}

function Get-VectorRandomUnit {
    return [System.Numerics.Vector3]::Normalize((Get-VectorRandomInUnitSphere))
}

function Get-VectorRandomInHemisphere {
    param (
        [object] $Normal
    )
    $inUnitSphere = Get-VectorRandomInUnitSphere
    if([System.Numerics.Vector3]::Dot($inUnitSphere, $Normal) -gt 0.0) {
        return $inUnitSphere
    } else {
        return -$inUnitSphere
    }
}

# https://raytracing.github.io/books/RayTracingInOneWeekend.html#dielectrics/snell'slaw
function Get-VectorRefracted {
    param (
        [object] $Vector,
        [object] $Normal,
        [float] $RefractionRatio
    )
    $dotProduct = [System.Numerics.Vector3]::Dot(-$Vector, $Normal)
    $cosTheta = [Math]::Min($dotProduct, 1.0)

    $perpendicularRay = $RefractionRatio * ($Vector + ($cosTheta * $Normal))
    $parallelRay = -[Math]::Sqrt([Math]::Abs(1.0 - $perpendicularRay.LengthSquared())) * $Normal

    return $perpendicularRay + $parallelRay
}

# https://raytracing.github.io/books/RayTracingInOneWeekend.html#metal/mirroredlightreflection
function Get-VectorReflected {
    param (
        $Vector,
        $Normal
    )
    return $Vector - (2 * [System.Numerics.Vector3]::Dot($Vector, $Normal) * $Normal)
}

# https://raytracing.github.io/books/RayTracingInOneWeekend.html#dielectrics/schlickapproximation
function Get-VectorReflectance {
    param (
        [float] $CosineTheta,
        [float] $RefractionRatio
    )
    # TODO: something is broken with this
    $rZero = (1-$RefractionRatio) / (1+$RefractionRatio)
    $rZeroSquared = $rZero * $rZero
    return $rZeroSquared + (1-$rZeroSquared)*[Math]::Pow((1 - $CosineTheta), 5)
}

# https://raytracing.github.io/books/RayTracingInOneWeekend.html#metal/modelinglightscatterandreflectance
function Test-VectorNearZero {
    param (
        [object] $Vector
    )
    $nearZero = 1e-8
    return [Math]::Abs($Vector.X) -lt $nearZero -and [Math]::Abs($Vector.Y) -lt $nearZero -and [Math]::Abs($Vector.Z) -lt $nearZero
}

function Get-VectorScattered {
    param (
        [object] $Ray,
        [object] $HitRecord
    )

    $scattered = $null
    if($HitRecord.Material.Reflective) {
        $directionUnit = [System.Numerics.Vector3]::Normalize($Ray.Direction)
        $reflected = Get-VectorReflected -Vector $directionUnit -Normal $HitRecord.Normal
        $fuzzedReflected = $reflected + ($HitRecord.Material.Fuzz * (Get-VectorRandomInUnitSphere))
        $scattered = New-Ray -Origin $HitRecord.Point -Direction $fuzzedReflected
        if([System.Numerics.Vector3]::Dot($scattered.Direction, $HitRecord.Normal) -le 0) {
            return $null
        } else {
            return @{
                Direction = $scattered
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
        if($cannotRefract -or (Get-VectorReflectance -CosineTheta $cosTheta -RefractionRatio $refractionRatio) -gt ((Get-Random -Minimum 0 -Maximum 100) / 100.0)) {
            $direction = Get-VectorReflected -Vector $directionUnit -Normal $HitRecord.Normal
        } else {
            $direction = Get-VectorRefracted -Vector $directionUnit -Normal $HitRecord.Normal -RefractionRatio $refractionRatio
        }

        return @{
            Direction = New-Ray -Origin $HitRecord.Point -Direction $direction
            Attenuation = @{
                Red = 1.0
                Green = 1.0
                Blue = 1.0
            }
        }
    } else {
        $scatterDirection = $HitRecord.Normal + (Get-VectorRandomUnit)
        if(Test-VectorNearZero -Vector $scatterDirection) {
            $scatterDirection = $HitRecord.Normal
        }
        return @{
            Direction = New-Ray -Origin $HitRecord.Point -Direction $scatterDirection
            Attenuation = @{
                Red = $HitRecord.Material.Rgb.Red / 255.0
                Green = $HitRecord.Material.Rgb.Green / 255.0
                Blue = $HitRecord.Material.Rgb.Blue / 255.0
            }
        }
    }
}

Export-ModuleMember -Function "*-*"