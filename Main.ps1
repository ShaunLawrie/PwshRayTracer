#Requires -Version 7
param (
    [string] $Note
)

function Invoke-Renderer {
    param (
        [int] $ImageWidth = 136,
        [int] $LeftPadding = 0,
        [object] $Scene,
        [int] $SamplesPerPixel = 15,
        [int] $SampleFuzziness = 100,
        [int] $MaxRayRecursionDepth = 10,
        [float] $FieldOfView = 90.0,
        [object] $LookFrom = [System.Numerics.Vector3]::new(0, 0, 0),
        [object] $LookAt = [System.Numerics.Vector3]::new(0, 0, -1),
        [object] $CameraUp = [System.Numerics.Vector3]::new(0, 1, 0),
        [float] $Aperture = 1.0,
        [float] $FocusDistance = ($LookFrom - $LookAt).Length(),
        [string] $Note
    )

    # Image
    $aspectWidth = 16.0
    $aspectHeight = 9.0
    $aspectRatio = $aspectWidth / $aspectHeight
    $imageHeight = [int]($ImageWidth / $aspectRatio)

    if($ImageWidth -ge ([Console]::WindowWidth / 2) -or $imageHeight -ge ([Console]::WindowHeight - 2)) {
        throw "Image width or $ImageWidth is trying to render wider or taller than the terminal window, try zooming out"
    }

    # Left terminal padding
    $leftPadding = [int](([Console]::WindowWidth / 2) - $ImageWidth)
    $title = "Powershell Ray Tracer 0.1a (speed)"

    Write-Host "$(' ' * $LeftPadding) $title"

    # setup camera inline
    $theta = $FieldOfView * ([math]::PI / 180)
    $h = [Math]::Tan($theta / 2.0)
    $viewportHeight = 2.0 * $h
    $viewportWidth = $aspectRatio * $viewportHeight

    $cameraW = [System.Numerics.Vector3]::Normalize($LookFrom - $LookAt)
    $cameraU = [System.Numerics.Vector3]::Normalize([System.Numerics.Vector3]::Cross($CameraUp, $cameraW))
    $cameraV = [System.Numerics.Vector3]::Cross($cameraW, $cameraU)

    $cameraOrigin = $LookFrom
    $cameraHorizontal = $FocusDistance * $viewportWidth * $cameraU
    $cameraVertical = $FocusDistance * $viewportHeight * $cameraV
    $cameraLowerLeftCorner = $cameraOrigin - ($cameraHorizontal / 2.0) - ($cameraVertical / 2.0) - ($FocusDistance * $cameraW)
    $cameraLensRadius = $Aperture / 2.0

    $previousProgressPreference = $ProgressPreference
    $ProgressPreference = "SilentlyContinue"
    $info = Get-ComputerInfo
    $ProgressPreference = $previousProgressPreference
    $threads = $info.CsProcessors.NumberOfLogicalProcessors + 4
    $streams = [System.Collections.ArrayList]::new()
    $linesPerThread = [int]($imageHeight / $threads)
    $progressChunks = 100 / $linesPerThread
    for($i = 0; $i -lt $threads; $i++) {
        $streams.Add(
            @{
                Index = $i
                StartLine = ($i * $linesPerThread)
                EndLine = (($i + 1) * $linesPerThread)
            }
        ) | Out-Null
        [Console]::WriteLine(("$(' ' * $LeftPadding) [" + (" " * 100) + "] thread $($i.ToString("00")) 0%"))
    }
    Start-Sleep -Seconds 1

    $mutex = New-Object System.Threading.Mutex($false, "ProgressUpdateMutex")
    $currentCursorPosition = $Host.UI.RawUI.CursorPosition
    $currentCursorPosition.Y = $currentCursorPosition.Y - $threads

    $parallelResults = $streams | Foreach-Object -ThrottleLimit $threads -Parallel {

        function Get-RayColor {
            param (
                $Point,
                $Direction,
                $RayBouncedOff = $null,
                [int] $Depth
            )
        
            $TMin = 0.001
        
            if ($Depth -le 0) {
                return @{
                    0 = 0
                    1 = 0
                    2 = 0
                }
            }
        
            $hitRecordHitPoint = $null
            $hitRecordNormal = $null
            $hitRecordFrontFace = $true
            $hitRecordMaterial = $null
            $hitRecordObject = $null
            $closestSoFar = ([float]::PositiveInfinity)
        
            $a = $Direction.LengthSquared()
            <# THIS IS THE HOT PATH #>
            if($RayBouncedOff -and $false) {
                if($Direction.X -gt $TMin) {
                    $targets = $RayBouncedOff.Righties
                } elseif($Direction.X -lt $TMin) {
                    $targets = $RayBouncedOff.Lefties
                } else {
                    $targets = $RayBouncedOff.Lefties + $RayBouncedOff.Righties
                }
                foreach($object in $targets) {
                    $oc = $Point - $object[0]
                    $halfB = [System.Numerics.Vector3]::Dot($oc, $Direction)
                    $c = $oc.LengthSquared() - $object[3]
                    $discriminant = ($halfB * $halfB) - ($a * $c)
            
                    if($discriminant -lt 0) {
                        continue
                    }
                    <# THIS IS THE END OF THE HOT PATH #>
            
                    $sqrtd = [Math]::Sqrt($discriminant)
            
                    $root = (-$halfB - $sqrtd) / $a;
                    if ($root -lt $TMin -or $closestSoFar -lt $root) {
                        $root = (-$halfB + $sqrtd) / $a
                        if ($root -lt $TMin -or $closestSoFar -lt $root) {
                            continue
                        }
                    }
            
                    $distance = $Direction * $root 
                    $hitPoint = $Point + $distance
            
                    $outwardNormal = ($hitPoint - $object[0]) / $object[1];
            
                    $frontFace = [System.Numerics.Vector3]::Dot($Direction, $outwardNormal) -lt 0
                    $normal = if($frontFace) { $outwardNormal } else { -$outwardNormal }
            
                    $hitRecordHitPoint = $hitPoint
                    $hitRecordNormal = $normal
                    $hitRecordFrontFace = $frontFace
                    $hitRecordMaterial = $object[2]
                    $hitRecordObject = $object
                    
                    $closestSoFar = $root
                }
            } else {
                # Exhaustive search
                foreach($object in $Scene) {
                    $oc = $Point - $object[0]
                    $halfB = [System.Numerics.Vector3]::Dot($oc, $Direction)
                    $c = $oc.LengthSquared() - $object[3]
                    $discriminant = ($halfB * $halfB) - ($a * $c)
            
                    if($discriminant -lt 0) {
                        continue
                    }
                    <# THIS IS THE END OF THE HOT PATH #>
            
                    $sqrtd = [Math]::Sqrt($discriminant)
            
                    $root = (-$halfB - $sqrtd) / $a;
                    if ($root -lt $TMin -or $closestSoFar -lt $root) {
                        $root = (-$halfB + $sqrtd) / $a
                        if ($root -lt $TMin -or $closestSoFar -lt $root) {
                            continue
                        }
                    }
            
                    $distance = $Direction * $root 
                    $hitPoint = $Point + $distance
            
                    $outwardNormal = ($hitPoint - $object[0]) / $object[1];
            
                    $frontFace = [System.Numerics.Vector3]::Dot($Direction, $outwardNormal) -lt 0
                    $normal = if($frontFace) { $outwardNormal } else { -$outwardNormal }
            
                    $hitRecordHitPoint = $hitPoint
                    $hitRecordNormal = $normal
                    $hitRecordFrontFace = $frontFace
                    $hitRecordMaterial = $object[2]
                    $hitRecordObject = $object
                    
                    $closestSoFar = $root
                }
            }
        
            if($hitRecordHitPoint) {
                $scatteredDirectionPoint = $null
                $scatteredDirectionDirection = $null
                $scatteredAttenuationR = $null
                $scatteredAttenuationG = $null
                $scatteredAttenuationB = $null
                
                if($hitRecordMaterial[3]) {
                    $directionUnit = [System.Numerics.Vector3]::Normalize($Direction)
                    $reflected = $directionUnit - (2 * [System.Numerics.Vector3]::Dot($directionUnit, $hitRecordNormal) * $hitRecordNormal)
                    while ($True) {
                        $x = $global:Random.Next(100) / 100.0
                        $y = $global:Random.Next(100) / 100.0
                        $z = $global:Random.Next(100) / 100.0
                        $p = [System.Numerics.Vector3]::new($x, $y, $z)
                        if($p.LengthSquared() -ge 1) {
                            continue
                        }
                        $randomVectorInUnitSphere = $p
                        break
                    }
                    $fuzzedReflected = $reflected + ($hitRecordMaterial[4] * $randomVectorInUnitSphere)
                    $scatterDirection = @{
                        0 = $hitRecordHitPoint
                        1 = $fuzzedReflected
                    }
                    if([System.Numerics.Vector3]::Dot($scatterDirection[0], $hitRecordNormal) -gt 0) {
                        $hitRecordMaterialColor = $hitRecordMaterial[0]
                        $scatteredDirectionPoint = $hitRecordHitPoint
                        $scatteredDirectionDirection = $fuzzedReflected
                        $scatteredAttenuationR = $hitRecordMaterialColor[0] / 255.0
                        $scatteredAttenuationG = $hitRecordMaterialColor[1] / 255.0
                        $scatteredAttenuationB = $hitRecordMaterialColor[2] / 255.0
                    } else {
                        return @{
                            0 = 0
                            1 = 0
                            2 = 0
                        }
                    }
                } elseif($hitRecordMaterial[1]) {
                    $refractionRatio = if($hitRecordFrontFace) { 1.0 / $hitRecordMaterial[2] } else { $hitRecordMaterial[2] }
                    $directionUnit = [System.Numerics.Vector3]::Normalize($Direction)
        
                    $cosTheta = [Math]::Min([System.Numerics.Vector3]::Dot(-$directionUnit, $hitRecordNormal), 1.0)
                    $sinTheta = [Math]::Sqrt(1.0 - ($cosTheta * $cosTheta))
        
                    $cannotRefract = $refractionRatio * $sinTheta -gt 1.0
        
                    $direction = $null
                    $randomProb = $global:Random.Next(100) / 100.0
                    $rZero = (1-$refractionRatio) / (1+$refractionRatio)
                    $rZeroSquared = $rZero * $rZero
                    $reflectance = $rZeroSquared + (1-$rZeroSquared)*[Math]::Pow((1 - $cosTheta), 5)
                    if($cannotRefract -or $reflectance -gt $randomProb) {
                        $direction = $directionUnit - (2 * [System.Numerics.Vector3]::Dot($directionUnit, $hitRecordNormal) * $hitRecordNormal)
                    } else {
                        $dotProduct = [System.Numerics.Vector3]::Dot(-$directionUnit, $hitRecordNormal)
                        $cosTheta = [Math]::Min($dotProduct, 1.0)
                        $perpendicularRay = $refractionRatio * ($directionUnit + ($cosTheta * $hitRecordNormal))
                        $parallelRay = -[Math]::Sqrt([Math]::Abs(1.0 - $perpendicularRay.LengthSquared())) * $hitRecordNormal
                        $direction = $perpendicularRay + $parallelRay
                    }
        
                    $scatteredDirectionPoint = $hitRecordHitPoint
                    $scatteredDirectionDirection = $direction
                    $scatteredAttenuationR = 1.0
                    $scatteredAttenuationG = 1.0
                    $scatteredAttenuationB = 1.0
                } else {
                    while ($True) {
                        $x = $global:Random.Next(100) / 100.0
                        $y = $global:Random.Next(100) / 100.0
                        $z = $global:Random.Next(100) / 100.0
                        $p = [System.Numerics.Vector3]::new($x, $y, $z)
                        if($p.LengthSquared() -ge 1) {
                            continue
                        }
                        $randomInUnitSphere = $p
                        break
                    }
                    $randomUnit = [System.Numerics.Vector3]::Normalize($randomInUnitSphere)
                    $scatterDirection = $hitRecordNormal + $randomUnit
                    $nearZero = 1e-8
                    $vectorNearZero = [Math]::Abs($scatterDirection.X) -lt $nearZero -and [Math]::Abs($scatterDirection.Y) -lt $nearZero -and [Math]::Abs($scatterDirection.Z) -lt $nearZero
                    if($vectorNearZero) {
                        $scatterDirection = $hitRecordNormal
                    }
        
                    $scatteredDirectionPoint = $hitRecordHitPoint
                    $scatteredDirectionDirection = $scatterDirection
                    $hitRecordMaterialColor = $hitRecordMaterial[0]
                    $scatteredAttenuationR = $hitRecordMaterialColor[0] / 255.0
                    $scatteredAttenuationG = $hitRecordMaterialColor[1] / 255.0
                    $scatteredAttenuationB = $hitRecordMaterialColor[2] / 255.0
                }
                
                $color = Get-RayColor -Point $scatteredDirectionPoint -Direction $scatteredDirectionDirection -RayBouncedOff $hitRecordObject -Depth ($Depth - 1)
                return @{
                    0 = [Math]::Min($scatteredAttenuationR * $color[0], 255)
                    1 = [Math]::Min($scatteredAttenuationG * $color[1], 255)
                    2 = [Math]::Min($scatteredAttenuationB * $color[2], 255)
                }
            } else {
                $unitDirection = [System.Numerics.Vector3]::Normalize($Direction)
                $t = 0.5 * ($unitDirection.Y + 1.0)
                $startV = 255 * (1.0 - $t)
                $endR = 127 * $t
                $endG = 178 * $t
                $endB = 255 * $t
                return @{
                    0 = [Math]::Min($startV + $endR, 255)
                    1 = [Math]::Min($startV + $endG, 255)
                    2 = [Math]::Min($startV + $endB, 255)
                }
            }
        }

        $localBuffer = New-Object -TypeName "System.Text.StringBuilder" -ArgumentList ([int]((($using:ImageWidth * $using:imageHeight) + $using:imageHeight) / $using:threads))
        $localPpmBuffer = New-Object -TypeName "System.Text.StringBuilder" -ArgumentList ([int]((($using:ImageWidth * $using:imageHeight) + $using:imageHeight) / $using:threads))
        $localPixels = @{}
        $global:Random = New-Object -TypeName System.Random
        $global:Scene = $using:Scene
        $localMutex = $using:mutex
        for ($j = ($using:imageHeight - $_.StartLine); $j -ge ($using:imageHeight - $_.EndLine); $j--) {
            $localPixels[$j] = @{}
            for($i = 0; $i -le ($using:ImageWidth); $i++) {
                $localPixels[$j][$i] = @{
                    0 = 0 # red
                    1 = 0 # green
                    2 = 0 # blue
                }
            }
        }

        $rayTiming = Measure-Command {
            $lines = 0
            for ($j = ($using:imageHeight - $_.StartLine); $j -gt ($using:imageHeight - $_.EndLine); $j--) {
                $jPixels = $localPixels[$j]
                for ($i = 0; $i -le $using:ImageWidth; $i++) {
                    $currentPixel = $jPixels[$i]
                    for ($sample = 0; $sample -lt $using:SamplesPerPixel; $sample++) {
                        $u = ($i + ($global:Random.Next($using:SampleFuzziness) / 100.0)) / ($using:ImageWidth - 1.0)
                        $v = ($j + ($global:Random.Next($using:SampleFuzziness) / 100.0)) / ($using:imageHeight - 1.0)
                        $rd = $null
                        while($null -eq $rd) {
                            $x = ($global:Random.Next(200) - 100) / 100.0
                            $y = ($global:Random.Next(200) - 100) / 100.0
                            $p = [System.Numerics.Vector3]::new($x, $y, 0)
                            if($p.LengthSquared() -ge 1) {
                                continue
                            }
                            $rd = $using:cameraLensRadius * $p
                        }
                        $offset = ($using:cameraU * $rd.X) + ($using:cameraV * $rd.Y)

                        $newColor = Get-RayColor -Point ($using:cameraOrigin + $offset) -Direction ($using:cameraLowerLeftCorner + ($u * $using:cameraHorizontal) + ($v * $using:cameraVertical) - $using:cameraOrigin - $offset) -Depth $using:MaxRayRecursionDepth
                        
                        $currentPixel[0] += $newColor[0]
                        $currentPixel[1] += $newColor[1]
                        $currentPixel[2] += $newColor[2]
                    }

                    $r = [Math]::Clamp($currentPixel[0] / ($using:SamplesPerPixel - 1), 0, 255)
                    $g = [Math]::Clamp($currentPixel[1] / ($using:SamplesPerPixel - 1), 0, 255)
                    $b = [Math]::Clamp($currentPixel[2] / ($using:SamplesPerPixel - 1), 0, 255)
                    $null = $localBuffer.Append("$([Char]27)[48;2;${r};${g};${b}m  $([Char]27)[0m")
                    $null = $localPpmBuffer.AppendLine("${r} ${g} ${b}")
                    
                    $percent = [Math]::Round(($lines * $using:progressChunks) + ($i / $using:ImageWidth * $using:progressChunks))
                    $localMutex.WaitOne()
                    [Console]::SetCursorPosition($using:currentCursorPosition.X, ($using:currentCursorPosition.Y + $_.Index))
                    [Console]::Write(("$(' ' * $using:LeftPadding) [" + ("#" * $percent) + (" " * (100 - $percent)) + "] thread $($_.Index.ToString("00")) $([Math]::Round($percent, 1))%"))
                    $localMutex.ReleaseMutex()
                }
                $null = $localBuffer.AppendLine()
                $lines++
            }
        }

        return @{
            Index = $_.Index
            Buffer = $localBuffer
            PpmBuffer = $localPpmBuffer
            Timing = $rayTiming
        }
    }

    $rayTiming = @{
        TotalMilliseconds = ($parallelResults.Timing | Measure-Object -Maximum -Property TotalMilliseconds).Maximum
        TotalSeconds = ($parallelResults.Timing | Measure-Object -Maximum -Property TotalSeconds).Maximum
    }

    $buffers = $parallelResults | Sort-Object { $_.Index } | Select-Object -ExpandProperty Buffer
    $ppmBuffers = $parallelResults | Sort-Object { $_.Index } | Select-Object -ExpandProperty PpmBuffer
    [Console]::SetCursorPosition($currentCursorPosition.X, $currentCursorPosition.Y)
    foreach($buffer in $buffers) {
        $lines = $buffer.ToString().Split("`n")
        foreach($line in $lines) {
            if(![string]::IsNullOrWhiteSpace($line)) {
                Write-Host "$(' ' * $leftPadding) $line"
            }
        }
    }
    $ppm = "$PSScriptRoot\output.$((Get-Date).ToFileTime()).ppm"
    $ppmFileBuffer = New-Object -TypeName "System.Text.StringBuilder" -ArgumentList ([int]($ImageWidth * $imageHeight))
    $null = $ppmFileBuffer.AppendLine("P3")
    $null = $ppmFileBuffer.AppendLine("$($ImageWidth + 1) $imageHeight")
    $null = $ppmFileBuffer.AppendLine("255")
    
    foreach($ppmBuffer in $ppmBuffers) {
        $ppmData = $ppmBuffer.ToString().Split("`n")
        foreach($rgb in $ppmData) {
            if(![string]::IsNullOrWhiteSpace($rgb)) {
                $null = $ppmFileBuffer.Append("$($rgb.Trim()) ")
            }
        }
    }
    Set-Content -Path $ppm -NoNewline $ppmFileBuffer.ToString()

    $raysPerSecond = [Math]::Round(($ImageWidth * $imageHeight * $SamplesPerPixel) / $rayTiming.TotalSeconds, 1)
    $pixelsPerSecond = [Math]::Round(($ImageWidth * $imageHeight) / $rayTiming.TotalSeconds, 1)

    $stats = "[Aspect ratio = ${aspectWidth}:$aspectHeight, Image width = $ImageWidth, Antialiasing samples = $SamplesPerPixel, Sample fuzziness = $SampleFuzziness, Max ray recursion = $MaxRayRecursionDepth, Rays traced/sec = $raysPerSecond, Pixels/sec = $pixelsPerSecond, Render = $($rayTiming.TotalMilliseconds)ms]            "
    $statsSplit = (Select-String ".{1,$($ImageWidth * 2)}(\s|$)" -Input $stats -AllMatches).Matches.Value

    foreach($stat in $statsSplit) {
        Write-Host -ForegroundColor DarkGray "$(' ' * $leftPadding) $stat"
    }

    $statsOutput = @"
===========================================================
Note                 = $(if($Note) { $Note } else { "None" })
Date                 = $(Get-Date)
Scene                = MD5 $sceneHash
Aspect ratio         = ${aspectWidth}:$aspectHeight
Look From            = $LookFrom
Look At              = $LookAt
Image width          = $ImageWidth
Antialiasing samples = $SamplesPerPixel
Sample fuzziness     = $SampleFuzziness
Diffuse              = $Diffuse
Max ray recursion    = $MaxRayRecursionDepth
Rays traced/sec      = $raysPerSecond
Pixels/sec           = $pixelsPerSecond
Render               = $($rayTiming.TotalMilliseconds)ms
"@
    Add-Content "benchmarks.txt" -Value $statsOutput
}

$scene = @(
    # ground sphere
    @{
        0 = [System.Numerics.Vector3]::new(0, -1000.0, 0)
        1 = 1000.0
        2 = @{
            0 = @{0 = 128; 1 = 128; 2 = 128}
        }
        3 = 1000.0 * 1000.0
        Lefties = @()
        Righties = @()
        Label = "Ground"
    },
    # Refractive sphere
    @{
        0 = [System.Numerics.Vector3]::new(0, 1, 0)
        1 = 1.0
        2 = @{
            1 = $true
            2 = 1.5
            0 = @{0 = 128; 1 = 145; 2 = 128}
        }
        3 = 1.0 * 1.0
        Lefties = @()
        Righties = @()
        Label = "Glass"
    },
    # Colored sphere
    @{
        0 = [System.Numerics.Vector3]::new(-4, 1, 0)
        1 = 1.0
        2 = @{
            0 = @{0 = 102; 1 = 51; 2 = 26}
        }
        3 = 1.0 * 1.0
        Lefties = @()
        Righties = @()
        Label = "Colored"
    },
    # reflective
    @{
        0 = [System.Numerics.Vector3]::new(4, 1, 0)
        1 = 1.0
        2 = @{
            3 = $true
            4 = 0.05
            0 = @{0 = 179; 1 = 153; 2 = 128}
        }
        3 = 1.0 * 1.0
        Lefties = @()
        Righties = @()
        Label = "Mirrow"
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
                $scene += @{
                    0 = $center
                    1 = $r
                    2 = @{
                        0 = @{0 = (220 * $r1); 1 = (220 * $r2); 2 = (220 * $r3)}
                    }
                    3 = $r * $r
                    Lefties = @()
                    Righties = @()
                }
            } elseif($chooseMaterial -lt 0.965) {
                # reflective
                $scene += @{
                    0 = $center
                    1 = $r
                    2 = @{
                        3 = $true
                        4 = 0.05
                        0 = @{0 = (255 * $r1); 1 = (255 * $r2); 2 = (255 * $r3)}
                        #0 = @{0 = 255; 1 = 0; 2 = 0}
                    }
                    3 = $r * $r
                    Lefties = @()
                    Righties = @()
                }
            } else {
                # refractive
                $scene += @{
                    0 = $center
                    1 = $r
                    2 = @{
                        1 = $true
                        2 = 1.5
                        0 = @{0 = (220 * $r1); 1 = (220 * $r2); 2 = (220 * $r3)}
                    }
                    3 = $r * $r
                    Lefties = @()
                    Righties = @()
                }
            }
        }
    }
}

$scene += @{
    0 = [System.Numerics.Vector3]::new(4, 0.7, 2.2)
    1 = 0.4
    2 = @{
        0 = @{0 = 255; 1 = 255; 2 = 0}
    }
    3 = 0.4 * 0.4
    Lefties = @()
    Righties = @()
    Label = "Tennis"
}

$lookFrom = [System.Numerics.Vector3]::new(12, 1.9, 3)
$lookAt = [System.Numerics.Vector3]::new(0, 0, 0)
$distToFocus = 10.0
$aperture = 0.1

$counter = 0
# Populate the lefties and righties
foreach($outerObject in $scene) {
    $left = 0
    $right = 0
    $both = 0
    $center = $outerObject[0]
    $radius = $outerObject[1]
    $leftExtremity = [System.Numerics.Vector3]::new($center.X - $radius, $center.Y, $center.Z)
    $rightExtremity = [System.Numerics.Vector3]::new($center.X + $radius, $center.Y, $center.Z)
    #Write-Host "$($outerObject.Label) center $center leftEx $leftExtremity rightEx $rightExtremity"
    foreach($innerObject in $scene) {
        $innerCenter = $innerObject[0]
        $innerRadius = $innerObject[1]
        $innerLeftExtremity = [System.Numerics.Vector3]::new($innerCenter.X - $innerRadius, $innerCenter.Y, $innerCenter.Z)
        $innerRightExtremity = [System.Numerics.Vector3]::new($innerCenter.X + $innerRadius, $innerCenter.Y, $innerCenter.Z)
        $rightRelative = $rightExtremity - $innerLeftExtremity
        $leftRelative = $leftExtremity - $innerRightExtremity
        if($rightRelative.X -ge 0 -and $leftRelative.X -le 0) {
            #Write-Host "  $($innerObject.Label) BOTH center $($innerObject[0]) lr $leftRelative rr $rightRelative"
            $outerObject.Righties += $innerObject
            $outerObject.Lefties += $innerObject
            $both++
        } elseif($rightRelative.X -ge 0) {
            #Write-Host "  $($innerObject.Label) RIGHT center $($innerObject[0]) lr $leftRelative rr $rightRelative"
            $outerObject.Righties += $innerObject
            $right++
        } elseif($leftRelative.X -le 0) {
            #Write-Host "  $($innerObject.Label) LEFT center $($innerObject[0]) lr $leftRelative rr $rightRelative"
            $outerObject.Lefties += $innerObject
            $left++
        } else {
            throw "Fuck"
        }
    }
    $counter++
    Write-Host "  Object $($counter.ToString("000")) [left: $left, right: $right, both: $both, total: $($left + $right + $both)]"
}

[Console]::CursorVisible = $false

Invoke-Renderer -ImageWidth 120 `
    -Diffuse "scattered" `
    -LeftPadding 0 `
    -Scene $scene `
    -SamplesPerPixel 50 `
    -SampleFuzziness 100 `
    -MaxRayRecursionDepth 50 `
    -LookFrom $lookFrom `
    -LookAt $lookAt `
    -FieldOfView 20 `
    -Aperture $aperture `
    -FocusDistance $distToFocus `
    -Note $Note

[Console]::CursorVisible = $true