@{
    # Module identification
    RootModule = 'PPDS.Tools.psm1'
    ModuleVersion = '1.0.0'
    GUID = '8e4ee43b-7f82-482e-aad9-423721381dad'

    # Author information
    Author = 'Josh Smith'
    CompanyName = 'Power Platform Developer Suite'
    Copyright = '(c) 2025 Josh Smith. MIT License.'
    Description = 'PowerShell tools for Dataverse plugin deployment, drift detection, and CI/CD automation. Part of the Power Platform Developer Suite.'

    # Requirements - works on both PS 5.1 and PS 7+
    PowerShellVersion = '5.1'

    # Exported members
    FunctionsToExport = @(
        # Plugin commands
        'Get-DataversePluginRegistrations',
        'Deploy-DataversePlugins',
        'Get-DataversePluginDrift',
        'Remove-DataverseOrphanedSteps',

        # Auth commands
        'Connect-DataverseEnvironment'
    )

    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()

    # Private data for PowerShell Gallery
    PrivateData = @{
        PSData = @{
            Tags = @(
                'dataverse',
                'dynamics365',
                'powerplatform',
                'plugins',
                'deployment',
                'alm',
                'cicd',
                'devops'
            )
            LicenseUri = 'https://github.com/joshsmithxrm/ppds-tools/blob/main/LICENSE'
            ProjectUri = 'https://github.com/joshsmithxrm/ppds-tools'
            ReleaseNotes = 'Initial release with plugin deployment commands.'
        }
    }
}
