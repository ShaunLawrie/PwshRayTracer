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

function Get-VectorScalarMultiple {
    param(
        [object] $Vector,
        [object] $Multiplier
    )
    return [vec3]@{
        X = $Vector.X * $Multiplier
        Y = $Vector.Y * $Multiplier
        Z = $Vector.Z * $Multiplier
    }
}

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

function Convert-DegreesToRadians {
    param(
        [float] $Degrees
    )
    return $Degrees * ([math]::PI / 180)
}

function Get-NormalizedVector {
    param(
        [object] $Vector
    )
    $length = [math]::Sqrt(
        ($Vector.X * $Vector.X) + ($Vector.Y * $Vector.Y) + ($Vector.Z * $Vector.Z)
    )
    return [vec3]@{
        X = $Vector.X / $length
        Y = $Vector.Y / $length
        Z = $Vector.Z / $length
    }
}

function Get-PrimaryRay {
    param(
        [float] $PixelX,
        [float] $PixelY
    )
    $fieldOfViewdegrees = 90
    $fieldOfViewRadians = Convert-DegreesToRadians -Degrees $fieldOfViewdegrees
    $aspectRatio = $global:ImageWidth / $global:ImageHeight
    $normalizedX = ($PixelX + 0.5) / $global:ImageWidth
    $normalizedY = ($PixelY + 0.5) / $global:ImageHeight
    $screenX = ($normalizedX * 2) - 1
    $screenY = 1 - ($normalizedY * 2)
    $pixelCameraX = $screenX * $aspectRatio * [math]::Tan($fieldOfViewRadians / 2)
    $pixelCameraY = $screenY * [math]::Tan($fieldOfViewRadians / 2)
    $direction = New-Vector3 -X $pixelCameraX -Y $pixelCameraY -Z -1
    $normalizedDirection = Get-NormalizedVector -Vector $direction
    return [ray]@{
        Origin = New-Vector3 -X 0 -Y 0 -Z 20
        Direction = $normalizedDirection
    }
}

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

Export-ModuleMember -Function "*-*"