
$sceneObjects = @(
    # ground sphere
    @{
        Center = [System.Numerics.Vector3]::new(0, -1000.0, 0)
        Radius = 1000.0
        Material = @{
            Color = @{R = 128; G = 128; B = 128}
        }
        RadiusSquared = 1000.0 * 1000.0
        Label = "Ground"
    },
    # Refractive sphere
    @{
        Center = [System.Numerics.Vector3]::new(0, 1, 0)
        Radius = 1.0
        Material = @{
            Refractive = $true
            RefractiveIndex = 1.5
            Color = @{R = 128; G = 145; B = 128}
        }
        RadiusSquared = 1.0 * 1.0
        Label = "Glass"
    },
    # Colored sphere
    @{
        Center = [System.Numerics.Vector3]::new(-4, 1, 0)
        Radius = 1.0
        Material = @{
            Color = @{R = 102; G = 51; B = 26}
        }
        RadiusSquared = 1.0 * 1.0
        Label = "Colored"
    },
    # reflective
    @{
        Center = [System.Numerics.Vector3]::new(4, 1, 0)
        Radius = 1.0
        Material = @{
            Reflective = $true
            Fuzz = 0.05
            Color = @{R = 179; G = 153; B = 128}
        }
        RadiusSquared = 1.0 * 1.0
        Label = "Mirror"
})

Get-Random -SetSeed 3423 | Out-Null
for($a = -11; $a -lt 11; $a++) {
    for($b = -11; $b -lt 11; $b++) {
        $chooseMaterial = (Get-Random -Minimum -100 -Maximum 100) / 100.0
        $r1 = (Get-Random -Minimum 0 -Maximum 100) / 100.0
        $r2 = (Get-Random -Minimum 0 -Maximum 100) / 100.0
        $r3 = (Get-Random -Minimum 0 -Maximum 100) / 100.0
        $r = (Get-Random -Minimum 15 -Maximum 28) / 100.0
        $center = [System.Numerics.Vector3]::new(($a + 3.9 * $r1), $r, ($b + 7.9 * $r2))
        $p2 = [System.Numerics.Vector3]::new(4, 0.2, 0)

        if(($center - $p2).Length() -gt 1.0) {
            if($chooseMaterial -lt 0.7) {
                # nothing
            } elseif($chooseMaterial -lt 0.934) {
                # diffuse
                $sceneObjects += @{
                    Center = $center
                    Radius = $r
                    Material = @{
                        Color = @{R = (220 * $r1); G = (220 * $r2); B = (220 * $r3)}
                    }
                    RadiusSquared = $r * $r
                    Label = "Random Diffuse"
                }
            } elseif($chooseMaterial -lt 0.965) {
                # reflective
                $sceneObjects += @{
                    Center = $center
                    Radius = $r
                    Material = @{
                        Reflective = $true
                        Fuzz = 0.05
                        Color = @{R = (255 * $r1); G = (255 * $r2); B = (255 * $r3)}
                    }
                    RadiusSquared = $r * $r
                    Label = "Random Reflective"
                }
            } else {
                # refractive
                $sceneObjects += @{
                    Center = $center
                    Radius = $r
                    Material = @{
                        Refractive = $true
                        RefractiveIndex = 1.5
                        Color = @{R = (220 * $r1); G = (220 * $r2); B = (220 * $r3)}
                    }
                    RadiusSquared = $r * $r
                    Label = "Random Refractive"
                }
            }
        }
    }
}

$sceneObjects += @{
    Center = [System.Numerics.Vector3]::new(4, 0.7, 2.2)
    Radius = 0.4
    Material = @{
        Color = @{R = 255; G = 255; B = 0}
    }
    RadiusSquared = 0.4 * 0.4
    Label = "Tennis"
}

$scene = @{
    Camera = @{
        LookFrom = [System.Numerics.Vector3]::new(13, 2, 3)
        LookAt = [System.Numerics.Vector3]::new(0, 0, 0)
        CameraUp = [System.Numerics.Vector3]::new(0, 1, 0)
        ImageWidth = 120
        AspectRatio = "16:9"
        SamplesPerPixel = 500
        MaxRayRecursionDepth = 50
        FieldOfView = 20
        Aperture = 0.1
        FocusDistance = 10.0
    }
    Objects = $sceneObjects
}

Set-Content -Path "$PSScriptRoot/RayTracingInAWeekend.json" -Value (ConvertTo-Json $scene -Depth 25) -NoNewline