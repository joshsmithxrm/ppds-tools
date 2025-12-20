@{
    # Module identification
    RootModule = 'PPDS.Tools.psm1'
    ModuleVersion = '1.2.0'
    GUID = '8e4ee43b-7f82-482e-aad9-423721381dad'

    # Author information
    Author = 'Josh Smith'
    CompanyName = 'Power Platform Developer Suite'
    Copyright = '(c) 2025 Josh Smith. MIT License.'
    Description = 'PowerShell tools for Dataverse plugin deployment, data migration, drift detection, and CI/CD automation. Part of the Power Platform Developer Suite.'

    # Requirements - PowerShell 7+ required
    PowerShellVersion = '7.0'

    # Exported members
    FunctionsToExport = @(
        # Plugin commands
        'Get-DataversePluginRegistrations',
        'Deploy-DataversePlugins',
        'Get-DataversePluginDrift',
        'Remove-DataverseOrphanedSteps',

        # Auth commands
        'Connect-DataverseEnvironment',

        # Migration commands
        'Export-DataverseData',
        'Import-DataverseData',
        'Get-DataverseDependencyGraph',
        'Invoke-DataverseMigration'
    )

    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()

    # Private data for PowerShell Gallery
    PrivateData = @{
        PSData = @{
            Prerelease = 'alpha1'
            Tags = @(
                'dataverse',
                'dynamics365',
                'powerplatform',
                'plugins',
                'deployment',
                'migration',
                'alm',
                'cicd',
                'devops'
            )
            LicenseUri = 'https://github.com/joshsmithxrm/ppds-tools/blob/main/LICENSE'
            ProjectUri = 'https://github.com/joshsmithxrm/ppds-tools'
            ReleaseNotes = 'Data migration cmdlets (Export-DataverseData, Import-DataverseData, Get-DataverseDependencyGraph, Invoke-DataverseMigration). Requires ppds-migrate CLI tool.'
        }
    }
}
