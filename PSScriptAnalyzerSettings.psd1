@{
    # PSScriptAnalyzer Settings for PPDS.Tools

    Severity = @('Error', 'Warning')

    # Rules to exclude (intentional design decisions)
    ExcludeRules = @(
        # We use plural nouns intentionally for functions returning collections
        # e.g., Get-DataversePluginRegistrations returns multiple registrations
        'PSUseSingularNouns',

        # Write-Log is intentional - we want colored console output
        # Write-Host is appropriate for interactive logging
        'PSAvoidUsingWriteHost',

        # Write-Log is a common pattern name, not overwriting the built-in
        # (the built-in was added in PS 7.2 and is different)
        'PSAvoidOverwritingBuiltInCmdlets',

        # Private helper functions receive WhatIf from callers (public functions)
        # They don't need SupportsShouldProcess - they pass through the switch
        'PSUseShouldProcessForStateChangingFunctions',
        'PSUseSupportsShouldProcess',

        # PSShouldProcess false positive - Deploy-DataversePlugins checks $WhatIfPreference
        # directly which is the recommended pattern for complex WhatIf scenarios
        'PSShouldProcess',

        # Event handler parameters ($sender, $args) are required by .NET delegate signature
        # even if not all are used in the implementation
        'PSReviewUnusedParameter',

        # Connect-DataverseEnvironment accepts Username/Password for legacy auth scenarios
        # This is a CLI wrapper - credentials are passed to CLI which handles them securely
        # PSCredential would add unnecessary complexity since we'd extract plain text anyway
        'PSAvoidUsingUsernameAndPasswordParams'
    )

    Rules = @{
        # Configure specific rules
        PSAvoidUsingCmdletAliases = @{
            Enable = $true
        }
    }
}
