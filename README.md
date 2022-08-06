# Scale a PowerShell RayTracer on AWS Lambda

https://aws.amazon.com/blogs/compute/introducing-the-powershell-custom-runtime-for-aws-lambda/

## Pre-requisites
 - Terraform installed and available in your PATH with version greater than or equal to 1.2
 - Git installed and available in your PATH
 - AWS credentials configured for your current shell session via environment variables or default aws cli credential managers

## Run

```pwsh
# Build the lambda powershell base layer
.\Build.ps1
# Deploy the lambda and the underlying infrastructure to a new VPC in ap-southeast-2 (Terraform will confirm before applying changes)
.\Deploy.ps1
# 
```