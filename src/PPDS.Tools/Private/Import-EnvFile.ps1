function Import-EnvFile {
    <#
    .SYNOPSIS
        Loads environment variables from a .env file.
    .PARAMETER Path
        Path to the .env file. If not specified, tries .env.dev then .env
    .OUTPUTS
        Returns $true if file was loaded, $false otherwise.
    #>
    param(
        [string]$Path
    )

    # Determine which file to load
    $filesToTry = @()
    if (-not [string]::IsNullOrWhiteSpace($Path)) {
        $filesToTry += $Path
    }
    else {
        # Default search order
        $scriptRoot = if ($PSScriptRoot) { Split-Path $PSScriptRoot -Parent } else { Get-Location }
        $filesToTry += Join-Path $scriptRoot ".env.dev"
        $filesToTry += Join-Path $scriptRoot ".env"
    }

    foreach ($file in $filesToTry) {
        if (Test-Path $file) {
            Write-Log "Loading environment from: $file"

            $content = Get-Content $file -ErrorAction SilentlyContinue
            foreach ($line in $content) {
                # Skip comments and empty lines
                if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith("#")) {
                    continue
                }

                # Parse KEY=VALUE
                $parts = $line -split "=", 2
                if ($parts.Count -eq 2) {
                    $key = $parts[0].Trim()
                    $value = $parts[1].Trim()

                    # Remove surrounding quotes if present
                    if (($value.StartsWith('"') -and $value.EndsWith('"')) -or
                        ($value.StartsWith("'") -and $value.EndsWith("'"))) {
                        $value = $value.Substring(1, $value.Length - 2)
                    }

                    # Set environment variable
                    [Environment]::SetEnvironmentVariable($key, $value, "Process")
                }
            }

            Write-LogSuccess "Environment loaded from: $file"
            return $true
        }
    }

    Write-LogDebug "No .env file found"
    return $false
}

function Get-EnvVar {
    <#
    .SYNOPSIS
        Gets an environment variable with optional fallback.
    #>
    param(
        [string]$Name,
        [string]$Default = $null
    )

    $value = [Environment]::GetEnvironmentVariable($Name)
    if ([string]::IsNullOrWhiteSpace($value)) {
        return $Default
    }
    return $value
}
