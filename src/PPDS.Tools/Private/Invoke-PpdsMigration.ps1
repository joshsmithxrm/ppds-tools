function Invoke-PpdsMigration {
    <#
    .SYNOPSIS
        Reads the migration CLI's JSON-lines progress from stderr.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string[]]$Arguments
    )
    Write-Verbose "Running PPDS $($Arguments[0]) $($Arguments[1])"
    try {
        $result = Invoke-PpdsProcess -FilePath (Get-PpdsCli) -Arguments $Arguments -StandardErrorHandler {
            param($line)
            try { $event = $line | ConvertFrom-Json -ErrorAction Stop }
            catch { Write-Verbose $line; return }
            if ($event.entity -and $event.total -gt 0 -and $event.phase -in @('exporting', 'importing', 'deferred')) {
                $percent = [math]::Clamp([math]::Round(100 * $event.current / $event.total), 0, 100)
                Write-Progress -Activity 'PPDS migration' -Status "$($event.phase): $($event.entity) ($($event.current)/$($event.total))" -PercentComplete $percent
            }
            if ($event.message) { Write-Verbose $event.message }
        }
    }
    finally {
        Write-Progress -Activity 'PPDS migration' -Completed
    }
    if ($result.ExitCode -ne 0) {
        # All nonzero codes are failures, including validation/auth/safety refusals.
        throw (Get-PpdsFailureMessage -Result $result -Arguments $Arguments)
    }
    $completion = $null
    foreach ($line in ($result.StdErr -split '\r?\n')) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        try { $event = $line | ConvertFrom-Json -ErrorAction Stop }
        catch { continue }
        if ($event.phase -eq 'error') {
            throw "PPDS migration failed: $($event.message)"
        }
        # Copy reports export then import; ignore the later cleanup 'complete'
        # message, which has no result fields.
        if ($event.phase -eq 'complete' -and $null -ne $event.PSObject.Properties['recordsProcessed']) {
            $completion = $event
        }
    }
    if ($null -eq $completion) {
        throw 'PPDS migration returned no completion result.'
    }
    if (-not $completion.success -or $completion.failureCount -gt 0) {
        throw "PPDS migration reported $($completion.failureCount) failed records."
    }
    return [PSCustomObject]@{
        RecordsProcessed = $completion.recordsProcessed
        RecordsFailed = $completion.failureCount
        Duration = [TimeSpan]::Parse($completion.duration, [Globalization.CultureInfo]::InvariantCulture)
    }
}
