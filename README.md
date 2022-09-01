# PowerShell RayTracer
A very slow raytracer in PowerShell that has been optimised from ~100 camera rays traced per second to 4000 rays per second on a 4GHz 6 core CPU with a few tricks:
 - Multithreading ray processing by spreading batches across iterations of `Foreach-Object -Parallel` with varying degrees of parallelism depending on the cores available in the execution environment.
 - Swapping custom powershell classes representing vectors with the [SIMD-accelerated Vector types in .NET](https://docs.microsoft.com/en-us/dotnet/standard/simd) to get more performance by processing calculations with hardware parallelism on the CPU where available.
 - Inlining all possible external function calls because this reduces parameter parsing overhead in PowerShell.

Because I've been learning a bit of serverless stuff I was curious as to how much faster I could run this using PowerShell in a webscale™ setup by distributing the processing over as many concurrently running lambdas as I could get in my AWS account:  
 - By using Lambda with large memory sizes to get more cores I had >250,000 camera rays per second (~62x my laptop speed) but I managed to rack up a $200 bill over a couple of bad runs 😅
 - Batching and sending messages across multiple threads I was able to get past the primary bottleneck of the speed of sending messages to SNS because that PowerShell commandlet can send 10 messages in a batch but the API round trip is pretty slow.

_There isn't a great reason that SNS was used over SQS other than I wanted to practice using it._  
![Crappy Diagram](/artifacts/diagram.png)  

![Crappy Render](/artifacts/render.gif)

The raytracer source is adapted from the tutorial [Ray Tracing in One Weekend by Peter Shirley](https://raytracing.github.io/books/RayTracingInOneWeekend.html) and has been translated from C++ to PowerShell.  
To run PowerShell natively on Lambda this uses the [AWS PowerShell Lambda Runtime λ](https://aws.amazon.com/blogs/compute/introducing-the-powershell-custom-runtime-for-aws-lambda/)

## Run Locally
```pwsh
# Run the local version of the ray tracer with no cloud magic
.\src\local\Main.ps1
```
The local runner uses two character wide "pixels" because it makes them kind of square but when I built the Lambda based script I realised I could double the perceived resolution by using [the ▄ lower half block character](https://en.wikipedia.org/wiki/Block_Elements) and setting the foreground and background to split a single character space into an upper and lower pixel.
```pwsh
Write-Host -ForegroundColor White -BackgroundColor DarkGray "▄" -NoNewline;
Write-Host -ForegroundColor DarkGray -BackgroundColor White "▄" -NoNewline;
Write-Host " Hello pixels"
```
![image](https://user-images.githubusercontent.com/13159458/187947761-a818b1de-f958-4adc-8d8e-8105dd0e666a.png)

## Pre-requisites for Cloud
 - Terraform installed and available in your PATH with version greater than or equal to 1.2
 - Git installed and available in your PATH
 - AWS credentials configured for your current shell session via environment variables or default aws cli credential managers
 - [Installed Powershell AWS.Tools.SimpleNotificationService, AWS.Tools.SQS, AWS.Tools.S3](https://docs.aws.amazon.com/powershell/latest/userguide/pstools-getting-set-up-windows.html) for sending messages to SNS and S3

## Run in the Cloud
```pwsh
# Build the lambda powershell base layer
.\Build.ps1
# Deploy the lambda et. al to ap-southeast-2 with your default aws profile (terraform apply will request manual confirmation)
.\Deploy.ps1 -Region "ap-southeast-2" -ProfileName "default"
# Run a raytracer with the default scene from raytracing in a weekend
.\Invoke.ps1
```
*I got the script to explicitly add resource policies to allow this to work with assumed roles if you have a multi-account setup but I'm not 100% it's working...*

Once the Lambda has been deployed the AWS Lambda support gives you a basic IDE that properly supports PowerShell syntax.  
![image](https://user-images.githubusercontent.com/13159458/187941858-d2970ced-14a1-4067-9cd0-fafd017a8e7b.png)

## How Much Further Can You Go With Spheres?

Using spheres and some math to move them around you can build some pretty complicated structures but it's obviously easier to handle triangles like in a real rendering engine.  
In the past I've used matrix transformations to rotate objects in 3d space but after following the description of Quaternions here https://www.youtube.com/watch?v=3BR8tK-LuB0 I was able to use the center of large spheres as origin points and pivot other smaller spheres around them with the built in Quaternion functions in the .NET Numerics library e.g.  
[`PowerShellHero.ps1`](src/scenes/PowerShellHero.ps1)
```pwsh
function New-CurveMadeOfSpheres {
    param ( ... )
    ... # for the full context see the actual file
    $startPoint = [System.Numerics.Vector3]::new($PivotPoint.X, $PivotPoint.Y, $PivotPoint.Z + $Radius)
    $direction = $startPoint - $PivotPoint
    for($step = 1; $step -le $Resolution; $step++) {
        $percent = $step / $Resolution
        $currentYaw = $StartYaw + (($EndYaw - $StartYaw) * $percent)
        $currentPitch = $StartPitch + (($EndPitch - $StartPitch) * $percent)
        $quaternion = [System.Numerics.Quaternion]::CreateFromYawPitchRoll($currentYaw, $currentPitch, 0)
        $rotatedDirection = [System.Numerics.Vector3]::Transform($direction, $quaternion)
        $newPoint = $pivotPoint + $rotatedDirection
        $objects += ...
    }
    return $objects
}

# Build the left eyeliner
$eyeObject = $sceneObjects | Where-Object { $_.Label -eq "Right eye" }
$sceneObjects += New-CurveMadeOfSpheres `
    -PivotPoint $eyeObject.Center `
    -Radius $eyeObject.Radius `
    -StartYaw -12 -EndYaw 90 `
    -StartPitch 5 -EndPitch -12 `
    -StartRadius 0.01 `
    -EndRadius 0.05
```

![Crappy Diagram](/artifacts/pwshhero.png)  

## To Go Faster
To go faster the complexity of the ray tracing would need to be improved by using something like Octree Space Partitioning to reduce the number of calculations required for each collision check but I was really just interested in using PowerShell for something it wasn't designed for and I've had my fun so I'll probably leave the project at this. Using [Chronometer by Kevin Marquette](https://github.com/KevinMarquette/Chronometer) I was able to easily identify that the majority of the time spent in the raytracer is spent in this collision check section:
```diff
RayTracer.psm1 Line Profiling

  [TotalMs, Count, AvgMs]  L#:    Line of code
=============================================================================================
  [0108ms,    134, 001ms]  29:    $closestSoFar = ([float]::PositiveInfinity)
  [0000ms,    134, 000ms]  30:
  [0099ms,    134, 001ms]  31:    $a = $Direction.LengthSquared()
  [0246ms,    134, 002ms]  32:    foreach($object in $global:Scene) {
- [56797ms, 65258, 001ms]  33:        $oc = $Point - $object[0]
- [56093ms, 65258, 001ms]  34:        $halfB = [System.Numerics.Vector3]::Dot($oc, $Direction)
- [56117ms, 65258, 001ms]  35:        $c = $oc.LengthSquared() - ($object[1] * $object[1])
- [56359ms, 65258, 001ms]  36:        $discriminant = ($halfB * $halfB) - ($a * $c)
- [56189ms, 65258, 001ms]  38:        if($discriminant -lt 0) {
- [109092ms,65055, 002ms]  39:            continue
- [0000ms,  65055, 000ms]  40:        }
  [0000ms,    203, 000ms]  41:
  [0178ms,    203, 001ms]  42:        $sqrtd = [Math]::Sqrt($discriminant)
```
