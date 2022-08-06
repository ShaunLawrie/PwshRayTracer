param (
    [string] $Region = "ap-southeast-2"
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$terraformInstalled = Get-Command "terraform" -ErrorAction "SilentlyContinue"

Push-Location
try {
    Set-Location "./infra"
    if($terraformInstalled) {
        Write-Host -ForegroundColor Green "Terraform init to get terraform ready"
        terraform init
        Write-Host -ForegroundColor Green "Terraform apply to deploy to a new VPC in AWS"
        terraform apply -var="region=$Region"
        if($LASTEXITCODE -ne 0) {
            Write-Error "Terraform apply failed"
        }
        Write-Host -ForegroundColor Green "Opening resource group view in the AWS console"
        Start-Process "https://$Region.console.aws.amazon.com/resource-groups/group/rg-pwshraytracer?region=$Region"
    } else {
        Write-Warning "Terraform is not installed so this cannot apply the changes to your AWS account"
    }
} finally {
    Pop-Location
}