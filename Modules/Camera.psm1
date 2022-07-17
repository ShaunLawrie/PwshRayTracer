# Camera
$script:ViewportHeight
$script:ViewportWidth
$script:FocalLength
$script:Origin
$script:Horizontal
$script:Vertical
$script:LowerLeftCorner

function Initialize-Camera {
    param (
        [float] $AspectRatio
    )
    $script:ViewportHeight = 2.0
    $script:ViewportWidth = $AspectRatio * $ViewportHeight
    $script:FocalLength = 1.0
    $script:Origin = [System.Numerics.Vector3]::Zero
    $script:Horizontal = [System.Numerics.Vector3]::new($ViewportWidth, 0, 0)
    $script:Vertical = [System.Numerics.Vector3]::new(0, $ViewportHeight, 0)
    $script:LowerLeftCorner = $Origin - ($Horizontal / 2) - ($Vertical / 2) - [System.Numerics.Vector3]::new(0, 0, $FocalLength)
}

function Get-CameraRay {
    param (
        [float] $U,
        [float] $V
    )
    return New-Ray -Origin $script:Origin -Direction ($script:LowerLeftCorner + ($U * $script:Horizontal) + ($V * $script:Vertical) - $script:Origin)
}