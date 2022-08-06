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
        terraform apply
    } else {
        Write-Warning "Terraform is not installed so this cannot apply the changes to your AWS account"
    }
} finally {
    Pop-Location
}