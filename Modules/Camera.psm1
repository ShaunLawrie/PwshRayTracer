$script:Origin
$script:Horizontal
$script:Vertical
$script:LowerLeftCorner
$script:LensRadius
$script:W
$script:U
$script:V

function Initialize-Camera {
    param (
        [float] $FieldOfView,
        [float] $AspectRatio,
        [System.Numerics.Vector3] $LookFrom,
        [System.Numerics.Vector3] $LookAt,
        [System.Numerics.Vector3] $CameraUp,
        [float] $Aperture,
        [float] $FocusDistance
    )
    $theta = Convert-DegreesToRadians -Degrees $FieldOfView
    $h = [Math]::Tan($theta / 2.0)
    $viewportHeight = 2.0 * $h
    $viewportWidth = $AspectRatio * $viewportHeight

    $script:W = [System.Numerics.Vector3]::Normalize($LookFrom - $LookAt)
    $script:U = [System.Numerics.Vector3]::Normalize([System.Numerics.Vector3]::Cross($CameraUp, $script:W))
    $script:V = [System.Numerics.Vector3]::Cross($script:W, $script:U)

    $script:Origin = $LookFrom
    $script:Horizontal = $FocusDistance * $viewportWidth * $script:U
    $script:Vertical = $FocusDistance * $viewportHeight * $script:V
    $script:LowerLeftCorner = $script:Origin - ($script:Horizontal / 2.0) - ($script:Vertical / 2.0) - ($FocusDistance * $script:W)
    $script:LensRadius = $Aperture / 2.0
}

function Get-RandomInUnitDisk {
    while($true) {
        $x = (Get-Random -Minimum -100 -Maximum 100) / 100.0
        $y = (Get-Random -Minimum -100 -Maximum 100) / 100.0
        $p = [System.Numerics.Vector3]::new($x, $y, 0)
        if($p.LengthSquared() -ge 1) {
            continue
        }
        return $p
    }
}

function Get-CameraRay {
    param (
        [float] $S,
        [float] $T
    )
    $rd = $script:LensRadius * (Get-RandomInUnitDisk)
    $offset = ($script:U * $rd.X) + ($script:V * $rd.Y)

    return New-Ray -Origin ($script:Origin + $offset) -Direction ($script:LowerLeftCorner + ($S * $script:Horizontal) + ($T * $script:Vertical) - $script:Origin - $offset)
}