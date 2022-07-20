$ErrorActionPreference = "Stop"
. "$PSScriptRoot/Modules/Classes.ps1"
Get-ChildItem -Path "$PSScriptRoot/Modules" -Filter "*.psm1" | Foreach-Object { Import-Module $_.PsPath -Force }

Clear-HostAndHideCursor
while ($true) {
    try {
        Get-ChildItem -Path "$PSScriptRoot/Modules" -Filter "*.psm1" | Foreach-Object { Import-Module $_.PsPath -Force }

        $scene = @(
            # ground sphere
            [Sphere]@{
                Center = [System.Numerics.Vector3]::new(0, -1000.0, 0)
                Radius = 1000.0
                Material = [Material]@{
                    Rgb = [Rgb]@{Red = 128; Green = 128; Blue = 128}
                }
            },
            # Three large spheres
            [Sphere]@{
                Center = [System.Numerics.Vector3]::new(0, 1, 0)
                Radius = 1.0
                Material = [Material]@{
                    Refractive = $true
                    RefractiveIndex = 1.5
                }
            },
            [Sphere]@{
                Center = [System.Numerics.Vector3]::new(-4, 1, 0)
                Radius = 1.0
                Material = [Material]@{
                    Rgb = [Rgb]@{Red = 102; Green = 51; Blue = 26}
                }
            },
            [Sphere]@{
                Center = [System.Numerics.Vector3]::new(4, 1, 0)
                Radius = 1.0
                Material = [Material]@{
                    Reflective = $true
                    Fuzz = 0.05
                    Rgb = [Rgb]@{Red = 179; Green = 153; Blue = 128}
                }
            }
        )
        <#
        for($a = -11; $a -lt 11; $a++) {
            for($b = -11; $b -lt 11; $b++) {
                $chooseMaterial = (Get-Random -Minimum -100 -Maximum 100) / 100.0
                $r1 = (Get-Random -Minimum 0 -Maximum 100) / 100.0
                $r2 = (Get-Random -Minimum 0 -Maximum 100) / 100.0
                $r3 = (Get-Random -Minimum 0 -Maximum 100) / 100.0
                $center = [System.Numerics.Vector3]::new(($a + 0.9 * $r1), 0.2, ($b + 0.9 * $r2))

                $p2 = [System.Numerics.Vector3]::new(4, 0.2, 0)

                if(($center - $p2).Length() -gt 0.9) {
                    if($chooseMaterial -lt 0.8) {
                        # diffuse
                        $scene += [Sphere]@{
                            Center = $center
                            Radius = 0.2
                            Material = [Material]@{
                                Rgb = [Rgb]@{Red = (255 * $r1); Green = (255 * $r2); Blue = (255 * $r3)}
                            }
                        }
                    } elseif($chooseMaterial -lt 0.95) {
                        # reflective
                        $scene += [Sphere]@{
                            Center = $center
                            Radius = 0.2
                            Material = [Material]@{
                                Reflective = $true
                                Fuzz = $r1
                                Rgb = [Rgb]@{Red = (255 * $r1); Green = (255 * $r2); Blue = (255 * $r3)}
                            }
                        }
                    } else {
                        # refractive
                        $scene += [Sphere]@{
                            Center = $center
                            Radius = 0.2
                            Material = [Material]@{
                                Refractive = $true
                                RefractiveIndex = 1.5
                            }
                        }
                    }
                }
            }
        }
        #>

        $lookFrom = [System.Numerics.Vector3]::new(13, 2, 3)
        $lookAt = [System.Numerics.Vector3]::new(0, 0, 0)
        $distToFocus = 10.0
        $aperture = 0.1

        Invoke-Renderer -ImageWidth 80 `
            -Diffuse "scattered" `
            -LeftPadding 0 `
            -Scene $scene `
            -SamplesPerPixel 100 `
            -MaxRayRecursionDepth 50 `
            -LookFrom $lookFrom `
            -LookAt $lookAt `
            -FieldOfView 20 `
            -Aperture $aperture `
            -FocusDistance $distToFocus

        exit 0
    } catch {
        Write-Warning "Failed to load a module, retrying in 1 second: $_"
    } finally {
        Start-Sleep -Seconds 1
    }
}
