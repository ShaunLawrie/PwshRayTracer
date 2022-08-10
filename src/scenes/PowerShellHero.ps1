
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
        Center = [System.Numerics.Vector3]::new(0.17, -0.05, 5.384)
        Radius = 0.3
        Material = @{
            Color = @{R = 255; G = 255; B = 255}
        }
        RadiusSquared = 0.3 * 0.3
        Label = "Left Eye"
    },
    @{
        Center = [System.Numerics.Vector3]::new(0.162, -0.02, 5.384)
        Radius = 0.305
        Material = @{
            Color = @{R = 88; G = 206; B = 249}
        }
        RadiusSquared = 0.3 * 0.3
        Label = "Left Eyelid"
    },
    @{
        Center = [System.Numerics.Vector3]::new(-0.17, -0.05, 5.384)
        Radius = 0.305
        Material = @{
            Color = @{R = 255; G = 255; B = 255}
        }
        RadiusSquared = 0.3 * 0.3
        Label = "Right Eye"
    },
    @{
        Center = [System.Numerics.Vector3]::new(-0.162, -0.02, 5.384)
        Radius = 0.3
        Material = @{
            Color = @{R = 88; G = 206; B = 249}
        }
        RadiusSquared = 0.3 * 0.3
        Label = "Right Eyelid"
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
        Center = [System.Numerics.Vector3]::new(-0.285, -0.604, 4.493)
        Radius = 0.7
        Material = @{
            Color = @{R = 225; G = 225; B = 225}
        }
        RadiusSquared = 0.7 * 0.7
        Label = "Inner Collar Left"
    },
    @{
        Center = [System.Numerics.Vector3]::new(0.285, -0.604, 4.493)
        Radius = 0.7
        Material = @{
            Color = @{R = 225; G = 225; B = 225}
        }
        RadiusSquared = 0.7 * 0.7
        Label = "Inner Collar Right"
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
        Radius = 0.5
        Material = @{
            Color = @{R = 4; G = 3; B = 18}
        }
        RadiusSquared = 0.5 * 0.5
        Label = "Sleeve Left"
    },
    @{
        Center = [System.Numerics.Vector3]::new(1.067, -0.968, 4.649)
        Radius = 0.5
        Material = @{
            Color = @{R = 4; G = 3; B = 18}
        }
        RadiusSquared = 0.5 * 0.5
        Label = "Sleeve Right"
    }
)

$hairObject = $sceneObjects | Where-Object { $_.Label -eq "Hair" }
$lastObject = $null
for($i = 0; $i -lt 25; $i++) {
    $newRadius = $hairObject.Radius - (0.001 * $i)
    $sceneObject = @{
        Center = [System.Numerics.Vector3]::new($hairObject.Center.X - (0.03 * $i), $hairObject.Center.Y - (0.04 * $i), $hairObject.Center.Z - (0.03 * $i))
        Radius = $newRadius
        Material = $hairObject.Material
        RadiusSquared = $newRadius * $newRadius
        Label = "Hair $i"
    }
    $lastObject = $sceneObject
    $sceneObjects += $sceneObject
}

for($i = 0; $i -lt 15; $i++) {
    $newRadius = [Math]::Max($lastObject.Radius - (0.04 * $i), 0)
    $sceneObjects += @{
        Center = [System.Numerics.Vector3]::new($lastObject.Center.X + (0.03 * $i), $lastObject.Center.Y - (0.05 * $i), $lastObject.Center.Z + (0.06 * $i))
        Radius = $newRadius
        Material = $lastObject.Material
        RadiusSquared = $newRadius * $newRadius
        Label = "Hair Shrinking $i"
    }
}

for($i = 0; $i -lt 15; $i++) {
    $newRadius = $hairObject.Radius - 0.04
    $sceneObjects += @{
        Center = [System.Numerics.Vector3]::new($hairObject.Center.X - (0.03 * $i), $hairObject.Center.Y - 0.09, $hairObject.Center.Z - 0.32)
        Radius = $newRadius
        Material = $hairObject.Material
        RadiusSquared = $newRadius * $newRadius
        Label = "Hair 2 $i"
    }
}

for($i = 0; $i -lt 15; $i++) {
    $radius = 0.02
    $sceneObject = @{
        Center = [System.Numerics.Vector3]::new(-0.161 - (0.019 * $i), -0.04 + (0.0035 * $i), 5.683)
        Radius = $radius
        Material = @{
            Color = @{R = 1; G = 1; B = 15}
        }
        RadiusSquared = $radius * $radius
        Label = "Eyeliner Left"
    }
    $lastObject = $sceneObject
    $sceneObjects += $sceneObject
}

for($i = 0; $i -lt 4; $i++) {
    $radius = 0.02
    $sceneObject = @{
        Center = [System.Numerics.Vector3]::new($lastObject.Center.X, $lastObject.Center.Y - (0.01 * $i), 5.683)
        Radius = $radius
        Material = @{
            Color = @{R = 1; G = 1; B = 15}
        }
        RadiusSquared = $radius * $radius
        Label = "Eyeliner Left 2"
    }
    $sceneObjects += $sceneObject
}

for($i = 0; $i -lt 15; $i++) {
    $radius = 0.02
    $sceneObject = @{
        Center = [System.Numerics.Vector3]::new(0.161 + (0.019 * $i), -0.04 + (0.0035 * $i), 5.683)
        Radius = $radius
        Material = @{
            Color = @{R = 1; G = 1; B = 15}
        }
        RadiusSquared = $radius * $radius
        Label = "Eyeliner Right"
    }
    $lastObject = $sceneObject
    $sceneObjects += $sceneObject
}

for($i = 0; $i -lt 4; $i++) {
    $radius = 0.02
    $sceneObject = @{
        Center = [System.Numerics.Vector3]::new($lastObject.Center.X, $lastObject.Center.Y - (0.01 * $i), 5.683)
        Radius = $radius
        Material = @{
            Color = @{R = 1; G = 1; B = 15}
        }
        RadiusSquared = $radius * $radius
        Label = "Eyeliner Right 2"
    }
    $sceneObjects += $sceneObject
}

for($i = 0; $i -lt 30; $i++) {
    $radius = 0.04
    $sceneObject = @{
        Center = [System.Numerics.Vector3]::new(-0.45 + (0.019 * $i), 0.2 - (0.004 * $i), 5.523 + (0.007 * $i))
        Radius = $radius
        Material = @{
            Color = @{R = 255; G = 255; B = 255}
        }
        RadiusSquared = $radius * $radius
        Label = "Symbol"
    }
    $lastObject = $sceneObject
    $sceneObjects += $sceneObject
}

for($i = 0; $i -lt 40; $i++) {
    $radius = 0.04
    $sceneObject = @{
        Center = [System.Numerics.Vector3]::new(0.15 - (0.012 * $i), -0.3 - (0.004 * $i), 5.683)
        Radius = $radius
        Material = @{
            Color = @{R = 255; G = 255; B = 255}
        }
        RadiusSquared = $radius * $radius
        Label = "Symbol"
    }
    $sceneObjects += $sceneObject
}

$scene = @{
    Camera = @{
        LookFrom = [System.Numerics.Vector3]::new(0, 0, 10)
        LookAt = [System.Numerics.Vector3]::new(0, 0, 0)
        CameraUp = [System.Numerics.Vector3]::new(0, 1, 0)
        ImageWidth = 100
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