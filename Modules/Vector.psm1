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

Export-ModuleMember -Function "*-*"