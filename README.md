# Scale a PowerShell RayTracer on AWS Lambda

https://aws.amazon.com/blogs/compute/introducing-the-powershell-custom-runtime-for-aws-lambda/

```
# Clone the awslabs powershell runtime repository so we can build the powershell runtime
git clone git@github.com:awslabs/aws-lambda-powershell-runtime.git
# Build the layer (this downloads the microsoft provided powershell binaries into the layer source folder)
.\aws-lambda-powershell-runtime\powershell-runtime\build-PwshRuntimeLayer.ps1
# Build a zip for terraform to upload as a custom layer
Compress-Archive -Path .\aws-lambda-powershell-runtime\powershell-runtime\pwsh-runtime\* -DestinationPath ".\artifacts\pwsh_lambda_layer_payload.zip"
```