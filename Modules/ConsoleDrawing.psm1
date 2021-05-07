Function Write-HostBuffer {
    param(
        [string] $Buffer
    )
    [Console]::SetCursorPosition(0,0)
    Write-Host -NoNewline $Buffer
}

Function Clear-HostAndHideCursor {
    Clear-Host
    [Console]::CursorVisible = $false
}

Function Reset-Host {
    Clear-Host
    [Console]::CursorVisible = $true
}

Export-ModuleMember -Function "*-*"