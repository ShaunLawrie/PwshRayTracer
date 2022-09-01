# Scale a PowerShell RayTracer on AWS Lambda
A very slow raytracer in PowerShell that has been optimised from ~100 camera rays traced per second to 4000 rays per second on a 4GHz 6 core CPU with a few tricks:
 - Multithreading ray processing by spreading batches across iterations of `Foreach-Object -Parallel` with varying degrees of parallelism depending on the cores available in the execution environment.
 - Swapping custom powershell classes representing vectors with the [SIMD-accelerated Vector types in .NET](https://docs.microsoft.com/en-us/dotnet/standard/simd) to get more performance by processing calculations with hardware parallelism on the CPU where available.
 - Inlining all possible external function calls because this reduces parameter parsing overhead in PowerShell.

Because I've been learning a bit of serverless stuff I was curious as to how much faster I could run this using PowerShell in a webscale™ setup by distributing the processing over as many concurrently running lambdas as I could get in my AWS account and by:  
 - Using Lambda with large memory sizes to get more cores (I had >250,000 camera rays per second ~62x my laptop speed but I also racked up a $200 bill over a couple of days 😅)
 - Batching and sending messages across multiple threads because getting the workload delivered to lambda was the primary bottleneck.
 - I could have used SQS on both sides of the Lambda but wanted to play with configuring SNS as well.

![Crappy Diagram](/artifacts/diagram.png)

![Crappy Render](/artifacts/render.gif)

The raytracer source is adapted from the tutorial [Ray Tracing in One Weekend by Peter Shirley](https://raytracing.github.io/books/RayTracingInOneWeekend.html) and has been translated from C++ to PowerShell.  
To run PowerShell natively on Lambda this uses the [AWS PowerShell Lambda Runtime λ](https://aws.amazon.com/blogs/compute/introducing-the-powershell-custom-runtime-for-aws-lambda/)

## Pre-requisites
 - Terraform installed and available in your PATH with version greater than or equal to 1.2
 - Git installed and available in your PATH
 - AWS credentials configured for your current shell session via environment variables or default aws cli credential managers
 - [Installed Powershell AWS.Tools.SimpleNotificationService, AWS.Tools.SQS](https://docs.aws.amazon.com/powershell/latest/userguide/pstools-getting-set-up-windows.html) for sending messages to SNS

## Run
```pwsh
# Build the lambda powershell base layer
.\Build.ps1
# Deploy the lambda et. al to ap-southeast-2 with your default aws profile (terraform apply will request manual confirmation)
.\Deploy.ps1 -Region "ap-southeast-2" -ProfileName "default"
# Run a raytracer with the default scene from raytracing in a weekend
.\Invoke.ps1
```
*If you are using a cross account role you need to add a policy statement to allow you to publish to the SNS topic because the default policy is to allow the account itself to publish*

## Run Locally
```pwsh
# Run the local version of the ray tracer with no cloud magic
.\src\local\Main.ps1
```

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
