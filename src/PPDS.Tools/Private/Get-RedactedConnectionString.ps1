function Get-RedactedConnectionString {
    <#
    .SYNOPSIS
        Redacts sensitive values from a connection string.

    .DESCRIPTION
        Replaces sensitive credential values in Dataverse connection strings with ***REDACTED***.
        This prevents accidental exposure of secrets in logs, verbose output, and error messages.

        Matches the same redaction pattern used by the PPDS.Dataverse SDK for consistency.

    .PARAMETER ConnectionString
        The connection string to redact.

    .OUTPUTS
        String. The connection string with sensitive values replaced by ***REDACTED***.

    .EXAMPLE
        Get-RedactedConnectionString "AuthType=ClientSecret;Url=https://org.crm.dynamics.com;ClientId=abc;ClientSecret=secret123"
        # Returns: "AuthType=ClientSecret;Url=https://org.crm.dynamics.com;ClientId=abc;ClientSecret=***REDACTED***"
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(ValueFromPipeline)]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$ConnectionString
    )

    process {
        if ([string]::IsNullOrEmpty($ConnectionString)) {
            return $ConnectionString
        }

        # Match SDK's sensitive keys (case-insensitive)
        # See: PPDS.Dataverse/Security/ConnectionStringRedactor.cs
        $sensitiveKeys = @(
            'ClientSecret'
            'Password'
            'Secret'
            'Key'
            'Pwd'
            'Token'
            'ApiKey'
            'AccessToken'
            'RefreshToken'
            'SharedAccessKey'
            'AccountKey'
            'Credential'
        )

        $result = $ConnectionString

        foreach ($key in $sensitiveKeys) {
            # Pattern handles:
            # - Key=value; (semicolon terminated)
            # - Key=value (end of string)
            # - Key="quoted value with spaces"; (quoted values)
            $result = $result -replace "(?i)($key=)(?:`"[^`"]*`"|[^;]+)", "`$1***REDACTED***"
        }

        return $result
    }
}
