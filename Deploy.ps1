param (
    [string] $Region = "ap-southeast-2",
    [switch] $SkipOpeningAwsConsole,
    [switch] $Force
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$terraformInstalled = Get-Command "terraform" -ErrorAction "SilentlyContinue"

Push-Location
try {
    Set-Location "./infra"
    if($terraformInstalled) {
        if(!(Test-Path ".terraform")) {
            Write-Host -ForegroundColor Green "Terraform init to get terraform ready"
            terraform init
        }
        Write-Host -ForegroundColor Green "Terraform apply to deploy PwshRaytracer in AWS"
        $userArn = Read-Host "Your AWS IAM User ARN is required for setting up the SQS/SNS policies that will allow you to publish and retrieve messages from the command line. Enter your ARN e.g. 'arn:aws:iam::1122334455:user/myusername'"

        if($Force) {
            terraform apply -var="region=$Region" -var="iam_user_arn=$userArn" -auto-approve
        } else {
            terraform apply -var="region=$Region" -var="iam_user_arn=$userArn"
        }
        if($LASTEXITCODE -ne 0) {
            Write-Error "Terraform apply failed"
        }
        if(!$SkipOpeningAwsConsole -and !$Force) {
            Write-Host -ForegroundColor Green "Opening resource group view in the AWS console"
            Start-Process "https://$Region.console.aws.amazon.com/resource-groups/group/rg-pwshraytracer?region=$Region"
        }
    } else {
        Write-Warning "Terraform is not installed so this cannot apply the changes to your AWS account"
    }
} finally {
    Pop-Location
}