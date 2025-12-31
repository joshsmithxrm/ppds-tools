@{
    # Module identification
    RootModule = 'PPDS.Tools.psm1'
    ModuleVersion = '1.2.0'
    GUID = '8e4ee43b-7f82-482e-aad9-423721381dad'

    # Author information
    Author = 'Josh Smith'
    CompanyName = 'Power Platform Developer Suite'
    Copyright = '(c) 2025 Josh Smith. MIT License.'
    Description = 'PowerShell tools for Dataverse plugin deployment, data migration, drift detection, and CI/CD automation. Wraps the ppds CLI tool. Part of the Power Platform Developer Suite.'

    # Requirements - PowerShell 7+ required
    PowerShellVersion = '7.0'

    # Exported members
    FunctionsToExport = @(
        # Auth commands
        'Connect-DataverseEnvironment',
        'Get-DataverseProfile',
        'Get-DataverseProfiles',

        # Plugin commands
        'Get-DataversePluginRegistrations',
        'Deploy-DataversePlugins',
        'Get-DataversePluginDrift',
        'Remove-DataverseOrphanedSteps',
        'Get-DataversePlugins',

        # Data migration commands
        'Export-DataverseData',
        'Import-DataverseData',
        'Copy-DataverseData',
        'Get-DataverseDependencyGraph'
    )

    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @(
        'Invoke-DataverseMigration'  # Alias for Copy-DataverseData (backwards compat)
    )

    # Private data for PowerShell Gallery
    PrivateData = @{
        PSData = @{
            Prerelease = 'alpha2'
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
            ReleaseNotes = @'
## v1.2.0-alpha2 - CLI Wrapper Refactor

BREAKING CHANGES:
- All cmdlets now wrap the ppds CLI tool (requires PPDS.Cli dotnet tool)
- Removed DataverseConnection class - use profile-based authentication
- Authentication uses ppds auth profiles (Connect-DataverseEnvironment wraps 'ppds auth create')
- All cmdlets use -Profile and -Environment parameters instead of -Connection

New Cmdlets:
- Get-DataverseProfile: Get active authentication profile
- Get-DataverseProfiles: List all profiles
- Get-DataversePlugins: List registered plugins in environment
- Copy-DataverseData: Copy data between environments (replaces Invoke-DataverseMigration)

Renamed Cmdlets:
- Invoke-DataverseMigration -> Copy-DataverseData (alias preserved for compatibility)

Install the CLI: dotnet tool install --global PPDS.Cli
'@
        }
    }
}
