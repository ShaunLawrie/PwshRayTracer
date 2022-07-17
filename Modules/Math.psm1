function Convert-DegreesToRadians {
    param(
        [float] $Degrees
    )
    return $Degrees * ([math]::PI / 180)
}

Export-ModuleMember -Function "*-*"