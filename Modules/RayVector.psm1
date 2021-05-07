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
        [vec3] $Subtract,
        [vec3] $From
    )
    return [pscustomobject]@{
        PSTypeName = "vec3"
        X = $From.X - $Subtract.X
        Y = $From.Y - $Subtract.Y
        Z = $From.Z - $Subtract.Z
    }
}

function Get-VectorDistance {
    param(
        [vec3] $PointA,
        [vec3] $PointB
    )
    return [Math]::Sqrt([Math]::Pow($A.X - $B.X, 2) + [Math]::Pow($A.Y - $B.Y, 2) + [Math]::Pow($A.Z - $B.Z, 2))
}

function Get-PrimaryRay {
    param(
        [float] $X,
        [float] $Y
    )
    return New-Vector3 -X $X -Y $Y -Z 0
}

Export-ModuleMember -Function "*-*"