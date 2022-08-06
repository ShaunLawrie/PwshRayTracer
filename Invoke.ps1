param (
    [string] $Scene = "scenes/raytracinginaweekend.json"
)

Write-Host -NoNewline "Scene: "
Write-Host -ForegroundColor DarkGray "$Scene"
$data = Get-Content -Path $Scene | ConvertFrom-Json
Write-Host -NoNewline "Camera: "
Write-Host -ForegroundColor DarkGray ($data.Camera | ConvertTo-Json -Compress -Depth 5)
Write-Host -NoNewline "Objects: "
$padding = ""
$data.Objects | ForEach-Object {
    Write-Host -ForegroundColor DarkGray ($padding + ($_ | ConvertTo-Json -Compress -Depth 5))
    $padding = "         "
}