function Write-Log {
    <#
    .SYNOPSIS
        Writes a log message with timestamp and level.
    #>
    param(
        [string]$Message,
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR", "DEBUG")]
        [string]$Level = "INFO"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "INFO"    { "White" }
        "SUCCESS" { "Green" }
        "WARNING" { "Yellow" }
        "ERROR"   { "Red" }
        "DEBUG"   { "Gray" }
    }
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

function Write-LogSuccess { param([string]$Message) Write-Log $Message "SUCCESS" }
function Write-LogWarning { param([string]$Message) Write-Log $Message "WARNING" }
function Write-LogError { param([string]$Message) Write-Log $Message "ERROR" }
function Write-LogDebug { param([string]$Message) Write-Log $Message "DEBUG" }
