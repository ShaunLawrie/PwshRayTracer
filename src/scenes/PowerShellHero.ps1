function ConvertFrom-DegreesToRadians {
    param (
        [float] $Degrees
    )
    return ([Math]::PI / 180) * $Degrees
}

function New-CurveMadeOfSpheres {
    param (
        [System.Numerics.Vector3] $PivotPoint,
        [float] $Radius,
        [float] $StartYaw = 0,
        [float] $EndYaw = 90,
        [float] $StartPitch = 0,
        [float] $EndPitch = 90,
        [int] $Resolution = 25,
        [float] $StartRadius = 0.02,
        [float] $EndRadius = 0.02,
        [hashtable] $Color = @{ R = 0;  G = 0; B = 0 }
    )

    $StartYaw = ConvertFrom-DegreesToRadians $StartYaw
    $EndYaw = ConvertFrom-DegreesToRadians $EndYaw
    $StartPitch = ConvertFrom-DegreesToRadians $StartPitch
    $EndPitch = ConvertFrom-DegreesToRadians $EndPitch

    $objects = @()
    $startPoint = [System.Numerics.Vector3]::new($PivotPoint.X, $PivotPoint.Y, $PivotPoint.Z + $Radius)
    $direction = $startPoint - $PivotPoint
    for($step = 1; $step -lt $Resolution; $step++) {
        $percent = $step / $Resolution
        $currentYaw = $StartYaw + (($EndYaw - $StartYaw) * $percent)
        $currentPitch = $StartPitch + (($EndPitch - $StartPitch) * $percent)
        $currentRadius = $StartRadius + (($EndRadius - $StartRadius) * $percent)
        $quaternion = [System.Numerics.Quaternion]::CreateFromYawPitchRoll($currentYaw, $currentPitch, 0)
        $rotatedDirection = [System.Numerics.Vector3]::Transform($direction, $quaternion)
        $newPoint = $pivotPoint + $rotatedDirection
        $sceneObject = @{
            Center = $newPoint
            Radius = $currentRadius
            Material = @{
                Color = @{R = $Color.R; G = $Color.G; B = $Color.B}
            }
            RadiusSquared = $currentRadius * $currentRadius
            Label = "Curve of spheres"
        }
        $objects += $sceneObject
    }
    return $objects
}

function New-LineMadeOfSpheres {
    param (
        [System.Numerics.Vector3] $StartPoint,
        [System.Numerics.Vector3] $Direction,
        [float] $StartRadius,
        [float] $EndRadius,
        [int] $Resolution = 25,
        [hashtable] $Color = @{ R = 0;  G = 0; B = 0 },
        [string] $SizeChange = "linear"
    )

    $objects = @()

    for($step = 1; $step -le $Resolution; $step++) {
        $percent = $step / $Resolution
        if($SizeChange -eq "exponential") {
            $percent = (($step * $step) / $Resolution) / $Resolution
        }
        $currentRadius = $StartRadius + (($EndRadius - $StartRadius) * $percent)
        $sceneObject = @{
            Center = $StartPoint + ($Direction * $step)
            Radius = $currentRadius
            Material = @{
                Color = @{R = $Color.R; G = $Color.G; B = $Color.B}
            }
            RadiusSquared = $currentRadius * $currentRadius
            Label = "Line of spheres"
        }
        $objects += $sceneObject
    }

    return $objects
}

$eyeOffset = @{
    X = 0.147
    Y = -0.05
    Z = 5.395
}

$sceneObjects = @(
    @{
        Center = [System.Numerics.Vector3]::new(0, -1, -1000)
        Radius = 1000.0
        Material = @{
            Color = @{R = 209; G = 19; B = 129}
        }
        RadiusSquared = 1000.0 * 1000.0
        Label = "Bigger background purple sphere"
    },
    @{
        Center = [System.Numerics.Vector3]::new(9.559, -7.759, 22.759)
        Radius = 15.0
        Material = @{
            Color = @{R = 255; G = 255; B = 255}
        }
        RadiusSquared = 15.0 * 15.0
        Label = "Hidden diffuse"
    },
    @{
        Center = [System.Numerics.Vector3]::new(0, 0, 5)
        Radius = 0.7
        Material = @{
            Color = @{R = 88; G = 206; B = 249}
        }
        RadiusSquared = 0.7 * 0.7
        Label = "Face"
    },
    @{
        Center = [System.Numerics.Vector3]::new(0, 0.597, 5.39)
        Radius = 0.45
        Material = @{
            Color = @{R = 94; G = 32; B = 91}
        }
        RadiusSquared = 0.45 * 0.45
        Label = "Hair"
    },
    @{
        Center = [System.Numerics.Vector3]::new($eyeOffset.X, $eyeOffset.Y, $eyeOffset.Z)
        Radius = 0.3
        Material = @{
            Color = @{R = 255; G = 255; B = 255}
        }
        RadiusSquared = 0.3 * 0.3
        Label = "Right eye"
    },
    @{
        Center = [System.Numerics.Vector3]::new($eyeOffset.X - 0.0016, $eyeOffset.Y + 0.01, $eyeOffset.Z + 0.001)
        Radius = 0.3
        Material = @{
            Color = @{R = 88; G = 206; B = 249}
        }
        RadiusSquared = 0.3 * 0.3
        Label = "Right eyelid"
    },
    @{
        Center = [System.Numerics.Vector3]::new(-$eyeOffset.X, $eyeOffset.Y, $eyeOffset.Z)
        Radius = 0.3
        Material = @{
            Color = @{R = 255; G = 255; B = 255}
        }
        RadiusSquared = 0.3 * 0.3
        Label = "Left eye"
    },
    @{
        Center = [System.Numerics.Vector3]::new(-$eyeOffset.X + 0.0016, $eyeOffset.Y + 0.01, $eyeOffset.Z + 0.001)
        Radius = 0.3
        Material = @{
            Color = @{R = 88; G = 206; B = 249}
        }
        RadiusSquared = 0.3 * 0.3
        Label = "Left eyelid"
    },
    @{
        Center = [System.Numerics.Vector3]::new(-0.238, -0.45, 4.064)
        Radius = 1.0
        Material = @{
            Color = @{R = 225; G = 225; B = 225}
        }
        RadiusSquared = 1.0 * 1.0
        Label = "Collar Left"
    },
    @{
        Center = [System.Numerics.Vector3]::new(0.238, -0.45, 4.064)
        Radius = 1.0
        Material = @{
            Color = @{R = 225; G = 225; B = 225}
        }
        RadiusSquared = 1.0 * 1.0
        Label = "Collar Right"
    },
    @{
        Center = [System.Numerics.Vector3]::new(0, -1.146, 4.414)
        Radius = 1.0
        Material = @{
            Color = @{R = 10; G = 32; B = 97}
        }
        RadiusSquared = 1.0 * 1.0
        Label = "Shirt"
    },
    @{
        Center = [System.Numerics.Vector3]::new(-1.067, -0.968, 4.649)
        Radius = 0.45
        Material = @{
            Color = @{R = 4; G = 3; B = 18}
        }
        RadiusSquared = 0.5 * 0.5
        Label = "Sleeve left"
    },
    @{
        Center = [System.Numerics.Vector3]::new(1.067, -0.968, 4.649)
        Radius = 0.45
        Material = @{
            Color = @{R = 4; G = 3; B = 18}
        }
        RadiusSquared = 0.5 * 0.5
        Label = "Sleeve right"
    },
    @{
        Center = [System.Numerics.Vector3]::new(1.067, -0.968, 4.649)
        Radius = 0.45
        Material = @{
            Color = @{R = 4; G = 3; B = 18}
        }
        RadiusSquared = 0.5 * 0.5
        Label = "Sleeve right"
    }
)

# Build the hair falling down the left of the characters face
$hairObject = $sceneObjects | Where-Object { $_.Label -eq "Hair" }
$fallingHairs = New-LineMadeOfSpheres -StartPoint $hairObject.Center `
                -Direction @{ X = -0.03;  Y = -0.04; Z = -0.03 } `
                -StartRadius $hairObject.Radius `
                -EndRadius ($hairObject.Radius - 0.025) `
                -Resolution 25 `
                -Color $hairObject.Material.Color

# Build the hair shrinking down the front of the shoulder
$lastObject = $fallingHairs | Select-Object -Last 1
$shrinkingHairs = New-LineMadeOfSpheres -StartPoint $lastObject.Center `
                    -Direction @{ X = 0.03;  Y = -0.03; Z = 0.06 } `
                    -StartRadius ($lastObject.Radius) `
                    -EndRadius 0 `
                    -Resolution 15 `
                    -Color $lastObject.Material.Color

# Build the hair to the top left
$leftHairs = New-LineMadeOfSpheres -StartPoint @{ X = $hairObject.Center.X; Y = $hairObject.Center.Y - 0.09; Z = $hairObject.Center.Z - 0.32; } `
                    -Direction @{ X = -0.03;  Y = 0; Z = 0 } `
                    -StartRadius ($hairObject.Radius - 0.04) `
                    -EndRadius ($hairObject.Radius - 0.04) `
                    -Resolution 15 `
                    -Color $hairObject.Material.Color

$sceneObjects += $fallingHairs
$sceneObjects += $shrinkingHairs
$sceneObjects += $leftHairs

# Build the left eyeliner
$eyeObject = $sceneObjects | Where-Object { $_.Label -eq "Right eye" }
$sceneObjects += New-CurveMadeOfSpheres `
    -PivotPoint $eyeObject.Center `
    -Radius $eyeObject.Radius `
    -StartYaw -12 -EndYaw 90 `
    -StartPitch 5 -EndPitch -12 `
    -StartRadius 0.01 `
    -EndRadius 0.05
$sceneObjects += New-CurveMadeOfSpheres `
    -PivotPoint $eyeObject.Center `
    -Radius $eyeObject.Radius `
    -StartYaw 45 -EndYaw 90 `
    -StartPitch 5 -EndPitch -18 `
    -StartRadius 0.01 `
    -EndRadius 0.05

$eyeObject = $sceneObjects | Where-Object { $_.Label -eq "Left eye" }
$sceneObjects += New-CurveMadeOfSpheres `
    -PivotPoint $eyeObject.Center `
    -Radius $eyeObject.Radius `
    -StartYaw -90 -EndYaw 12 `
    -StartPitch -12 -EndPitch 5 `
    -StartRadius 0.05 `
    -EndRadius 0.01
$sceneObjects += New-CurveMadeOfSpheres `
    -PivotPoint $eyeObject.Center `
    -Radius $eyeObject.Radius `
    -StartYaw -90 -EndYaw -45 `
    -StartPitch -18 -EndPitch 5 `
    -StartRadius 0.05 `
    -EndRadius 0.01

# Face shell decorations
$faceObject = $sceneObjects | Where-Object { $_.Label -eq "Face" }
$faceShellRadius = ($faceObject.Radius - 0.167)
$faceShellSize = 0.17
$sceneObjects += New-CurveMadeOfSpheres `
    -PivotPoint $faceObject.Center `
    -Radius $faceShellRadius `
    -StartYaw -25 -EndYaw 15 `
    -StartPitch -20 -EndPitch 3 `
    -StartRadius $faceShellSize `
    -EndRadius $faceShellSize `
    -Color @{ R = 255; G = 255; B = 255; }
$sceneObjects += New-CurveMadeOfSpheres `
    -PivotPoint $faceObject.Center `
    -Radius $faceShellRadius `
    -StartYaw -65 -EndYaw 9 `
    -StartPitch 43 -EndPitch 16 `
    -StartRadius $faceShellSize `
    -EndRadius $faceShellSize `
    -Color @{ R = 255; G = 255; B = 255; }
$sceneObjects += New-CurveMadeOfSpheres `
    -PivotPoint $faceObject.Center `
    -Radius $faceShellRadius `
    -StartYaw 15 -EndYaw 90 `
    -StartPitch 35 -EndPitch 43 `
    -StartRadius $faceShellSize `
    -EndRadius $faceShellSize `
    -Color @{ R = 255; G = 255; B = 255; }
# Chin
$sceneObjects += New-LineMadeOfSpheres -StartPoint $faceObject.Center `
    -Direction @{ X = 0;  Y = -0.045; Z = 0.02 } `
    -StartRadius ($faceObject.Radius - 0.00001) `
    -EndRadius 0.27 `
    -Resolution 10 `
    -Color $faceObject.Material.Color
# Hair highlights
$hairHighlightsColor = @{ R = 255; G = 99; B = 189 }
$sceneObjects += New-CurveMadeOfSpheres `
    -PivotPoint $hairObject.Center `
    -Radius $hairObject.Radius `
    -StartYaw -12 -EndYaw 90 `
    -StartPitch -10 -EndPitch 35 `
    -StartRadius 0.01 `
    -EndRadius 0.03 `
    -Color $hairHighlightsColor
$sceneObjects += New-CurveMadeOfSpheres `
    -PivotPoint $hairObject.Center `
    -Radius $hairObject.Radius `
    -StartYaw 0 -EndYaw 90 `
    -StartPitch -45 -EndPitch 35 `
    -StartRadius 0.01 `
    -EndRadius 0.03 `
    -Color $hairHighlightsColor
$sceneObjects += New-CurveMadeOfSpheres `
    -PivotPoint $hairObject.Center `
    -Radius $hairObject.Radius `
    -StartYaw -45 -EndYaw 15 `
    -StartPitch 35 -EndPitch 40 `
    -StartRadius 0.005 `
    -EndRadius 0.02 `
    -Color $hairHighlightsColor

# Right hair
$rightHairSize = 0.05
$rightHairRadius = $faceObject.Radius - 0.02
$sceneObjects += New-CurveMadeOfSpheres `
    -PivotPoint $faceObject.Center `
    -Radius $rightHairRadius `
    -StartYaw 46 -EndYaw 90 `
    -StartPitch -20 -EndPitch 0 `
    -StartRadius $rightHairSize `
    -EndRadius $rightHairSize `
    -Color $hairHighlightsColor
$sceneObjects += New-CurveMadeOfSpheres `
    -PivotPoint $faceObject.Center `
    -Radius $rightHairRadius `
    -StartYaw 46 -EndYaw 90 `
    -StartPitch -20 -EndPitch -48 `
    -StartRadius $rightHairSize `
    -EndRadius $rightHairSize `
    -Color $hairHighlightsColor
$sceneObjects += New-CurveMadeOfSpheres `
    -PivotPoint $faceObject.Center `
    -Radius $rightHairRadius `
    -StartYaw 46 -EndYaw 90 `
    -StartPitch -20 -EndPitch -29 `
    -StartRadius $rightHairSize `
    -EndRadius $rightHairSize `
    -Color $hairHighlightsColor
$sceneObjects += New-CurveMadeOfSpheres `
    -PivotPoint $faceObject.Center `
    -Radius $rightHairRadius `
    -StartYaw 46 -EndYaw 90 `
    -StartPitch -20 -EndPitch -20 `
    -StartRadius $rightHairSize `
    -EndRadius $rightHairSize `
    -Color $hairHighlightsColor
$sceneObjects += New-CurveMadeOfSpheres `
    -PivotPoint $faceObject.Center `
    -Radius $rightHairRadius `
    -StartYaw 46 -EndYaw 90 `
    -StartPitch -20 -EndPitch -12 `
    -StartRadius $rightHairSize `
    -EndRadius $rightHairSize `
    -Color $hairHighlightsColor

$scene = @{
    Camera = @{
        LookFrom = [System.Numerics.Vector3]::new(0, 0, 10)
        LookAt = [System.Numerics.Vector3]::new(0, 0, 0)
        CameraUp = [System.Numerics.Vector3]::new(0, 1, 0)
        ImageWidth = 150
        AspectRatio = "26:9"
        SamplesPerPixel = 40
        MaxRayRecursionDepth = 50
        FieldOfView = 20
        Aperture = 0.1
        FocusDistance = 5.0
    }
    Objects = $sceneObjects
}

Set-Content -Path "$PSScriptRoot/PowerShellHero.json" -Value (ConvertTo-Json $scene -Depth 25) -NoNewline