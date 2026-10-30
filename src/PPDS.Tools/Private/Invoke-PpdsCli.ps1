function Protect-PpdsMessage {
    [CmdletBinding()]
    param(
        [AllowEmptyString()][AllowNull()][string]$Text,
        [string[]]$Arguments
    )
    if ($null -eq $Text) { return '' }
    for ($index = 0; $index -lt $Arguments.Count - 1; $index++) {
        if ($Arguments[$index] -in @('--clientSecret', '--certificatePassword', '--password', '-cs', '-cp')) {
            $secret = $Arguments[$index + 1]
            if ($secret) { $Text = $Text.Replace($secret, '[REDACTED]') }
        }
    }
    return $Text
}

function Get-PpdsFailureMessage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Result,
        [string[]]$Arguments
    )
    $detail = $null
    foreach ($text in @($Result.StdOut, $Result.StdErr)) {
        if (-not $text) { continue }
        try {
            $json = $text | ConvertFrom-Json -ErrorAction Stop
            if ($json.error.message) {
                $detail = "$($json.error.code): $($json.error.message)"
                break
            }
        }
        catch { continue }
    }
    if (-not $detail) {
        $detail = (@($Result.StdErr, $Result.StdOut) | Where-Object { $_ }) -join [Environment]::NewLine
    }
    $safeDetail = Protect-PpdsMessage -Text $detail -Arguments $Arguments
    return "PPDS CLI failed (exit code $($Result.ExitCode)). $safeDetail".Trim()
}

function Invoke-PpdsCli {
    <#
    .SYNOPSIS
        Executes a command and reads its complete JSON document or success envelope.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string[]]$Arguments,
        [switch]$Json,
        [switch]$AsJson,
        [switch]$AllowDrift,
        [switch]$WarnOnDrift,
        [switch]$Interactive
    )
    if ($Json) { $Arguments += @('--output-format', 'Json') }
    # Arguments may contain secrets. Log only the fixed command/group.
    Write-Verbose "Running PPDS $($Arguments[0]) $($Arguments[1])"
    $result = Invoke-PpdsProcess -FilePath (Get-PpdsCli) -Arguments $Arguments -Interactive:$Interactive
    if ($result.ExitCode -ne 0 -and -not ($AllowDrift -and $result.ExitCode -eq 1 -and $Json)) {
        throw (Get-PpdsFailureMessage -Result $result -Arguments $Arguments)
    }
    if ($Json) {
        try {
            $parsed = $result.StdOut | ConvertFrom-Json -ErrorAction Stop
            if ([string]::IsNullOrWhiteSpace($result.StdOut)) { throw 'Empty JSON output' }
        }
        catch {
            throw "PPDS CLI returned invalid JSON for $($Arguments[0]) $($Arguments[1])."
        }
        $isEnvelope = $null -ne $parsed.PSObject.Properties['version'] -and
            $null -ne $parsed.PSObject.Properties['success']
        if (($isEnvelope -and -not $parsed.success) -or
            ($result.ExitCode -ne 0 -and -not ($isEnvelope -and $parsed.success))) {
            throw (Get-PpdsFailureMessage -Result $result -Arguments $Arguments)
        }
        if ($result.StdErr) {
            Write-Verbose (Protect-PpdsMessage -Text $result.StdErr.Trim() -Arguments $Arguments)
        }
        if ($AllowDrift -and $WarnOnDrift -and $result.ExitCode -eq 1) {
            Write-Warning 'Drift detected. Run with -PassThru for details.'
        }
        if ($AsJson) { return $result.StdOut.Trim() }
        if ($isEnvelope) { return $parsed.data }
        return $parsed
    }
    if ($result.StdErr) { Write-Verbose (Protect-PpdsMessage -Text $result.StdErr.Trim() -Arguments $Arguments) }
    if ($result.StdOut) { Write-Verbose (Protect-PpdsMessage -Text $result.StdOut.Trim() -Arguments $Arguments) }
}
