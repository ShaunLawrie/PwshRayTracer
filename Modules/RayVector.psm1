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

function Get-VectorDistance {
    param(
        [object] $PointA,
        [object] $PointB
    )
    return [Math]::Sqrt([Math]::Pow($A.X - $B.X, 2) + [Math]::Pow($A.Y - $B.Y, 2) + [Math]::Pow($A.Z - $B.Z, 2))
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
    $screenY = ($normalizedY * 2) - 1
    $pixelCameraX = $screenX * $aspectRatio * [math]::Tan($fieldOfViewRadians / 2)
    $pixelCameraY = $screenY * [math]::Tan($fieldOfViewRadians / 2)
    $direction = New-Vector3 -X $pixelCameraX -Y $pixelCameraY -Z -1
    $normalizedDirection = Get-NormalizedVector -Vector $direction
    return [ray]@{
        Origin = New-Vector3 -X 0 -Y 0 -Z 0
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