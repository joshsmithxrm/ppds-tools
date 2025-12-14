function Get-DataversePluginRegistrations {
    <#
    .SYNOPSIS
        Extracts plugin registrations from compiled assemblies.

    .DESCRIPTION
        Loads compiled plugin DLLs via .NET reflection, finds all classes with
        [PluginStep] attributes, extracts step and image configurations, and
        generates registrations.json files for each plugin project.

    .PARAMETER AssemblyPath
        Path to a specific compiled plugin DLL.

    .PARAMETER RepositoryRoot
        Root of the repository to discover plugin projects.

    .PARAMETER Project
        Specific project name to extract. If not specified, extracts all.

    .PARAMETER Configuration
        Build configuration to use (Release or Debug). Default: Release.

    .PARAMETER Build
        Build projects before extraction.

    .PARAMETER OutputPath
        Custom output path for registrations.json. Default: project directory.

    .EXAMPLE
        Get-DataversePluginRegistrations -AssemblyPath "./bin/Release/net462/MyPlugins.dll" -OutputPath "./registrations.json"
        Extracts registrations from a specific assembly.

    .EXAMPLE
        Get-DataversePluginRegistrations -RepositoryRoot "." -Build
        Discovers and extracts all plugin projects in the repository.

    .OUTPUTS
        Array of assembly registration objects.
    #>
    [CmdletBinding()]
    param(
        [Parameter(ParameterSetName = "Assembly")]
        [string]$AssemblyPath,

        [Parameter(ParameterSetName = "Repository")]
        [string]$RepositoryRoot,

        [Parameter(ParameterSetName = "Repository")]
        [string]$Project,

        [Parameter(ParameterSetName = "Repository")]
        [ValidateSet("Release", "Debug")]
        [string]$Configuration = "Release",

        [Parameter(ParameterSetName = "Repository")]
        [switch]$Build,

        [Parameter()]
        [string]$OutputPath
    )

    Write-Log "Plugin Registration Extractor"

    # Single assembly mode
    if ($AssemblyPath) {
        if (-not (Test-Path $AssemblyPath)) {
            throw "Assembly not found: $AssemblyPath"
        }

        Write-Log "Extracting from: $AssemblyPath"

        $allTypeNames = Get-AllPluginTypeNames -DllPath $AssemblyPath
        $plugins = Get-PluginRegistrationsFromAssembly -DllPath $AssemblyPath

        $assemblyName = [System.IO.Path]::GetFileNameWithoutExtension($AssemblyPath)
        $relativePath = (Resolve-Path -Path $AssemblyPath -Relative -ErrorAction SilentlyContinue) -replace '\\','/'

        $assemblyReg = [PSCustomObject]@{
            name = $assemblyName
            type = "Assembly"
            solution = $null
            path = $relativePath
            allTypeNames = $allTypeNames
            plugins = $plugins
        }

        if ($OutputPath) {
            $registrationJson = ConvertTo-RegistrationJson -Assemblies @($assemblyReg)
            [System.IO.File]::WriteAllText($OutputPath, $registrationJson, [System.Text.UTF8Encoding]::new($false))
            Write-LogSuccess "Generated: $OutputPath"
        }

        return @($assemblyReg)
    }

    # Repository discovery mode
    if (-not $RepositoryRoot) {
        $RepositoryRoot = Get-Location
    }

    Write-Log "Repository: $RepositoryRoot"
    Write-Log "Configuration: $Configuration"

    Push-Location $RepositoryRoot
    try {
        Write-Log "Discovering plugin projects..."
        $allProjects = Get-PluginProjects -RepositoryRoot $RepositoryRoot

        if ($allProjects.Count -eq 0) {
            Write-LogWarning "No plugin projects found"
            return @()
        }

        Write-Log "Found $($allProjects.Count) plugin project(s)"

        $projects = if ($Project) {
            $filtered = $allProjects | Where-Object { $_.Name -eq $Project }
            if (-not $filtered) {
                Write-LogError "Project not found: $Project"
                Write-Log "Available projects:"
                $allProjects | ForEach-Object { Write-Log "  - $($_.Name) ($($_.Type))" }
                throw "Project not found: $Project"
            }
            $filtered
        } else {
            $allProjects
        }

        if ($Build) {
            Write-Log ""
            Write-Log "Building projects..."
            foreach ($proj in $projects) {
                Write-Log "Building: $($proj.Name)"
                $buildResult = & dotnet build $proj.ProjectPath -c $Configuration --nologo -v q 2>&1
                if ($LASTEXITCODE -ne 0) {
                    Write-LogError "Build failed for $($proj.Name)"
                    throw "Build failed"
                }
                Write-LogSuccess "  Built successfully"

                $dllPath = Join-Path $proj.ProjectDir "bin/$Configuration/net462/$($proj.Name).dll"
                if (Test-Path $dllPath) {
                    $proj.DllPath = $dllPath
                    $proj.RelativeDllPath = (Resolve-Path -Path $dllPath -Relative) -replace '\\','/'
                }
            }
        }

        Write-Log ""
        Write-Log "Extracting plugin registrations..."

        $allResults = @()
        $successCount = 0
        $errorCount = 0

        foreach ($proj in $projects) {
            Write-Log ""
            Write-Log "Processing: $($proj.Name) ($($proj.Type))"

            if (-not $proj.DllPath -or -not (Test-Path $proj.DllPath)) {
                Write-LogWarning "  DLL not found. Run with -Build or build manually first."
                $errorCount++
                continue
            }

            Write-Log "  DLL: $($proj.RelativeDllPath)"

            try {
                $allTypeNames = Get-AllPluginTypeNames -DllPath $proj.DllPath
                $plugins = Get-PluginRegistrationsFromAssembly -DllPath $proj.DllPath

                if ($plugins.Count -eq 0) {
                    Write-LogWarning "  No plugins with [PluginStep] attributes found"
                }

                Write-Log "  Found $($plugins.Count) plugin class(es) with step registrations"

                # Check for existing registrations.json to preserve solution property
                $existingJsonPath = Join-Path $proj.ProjectDir "registrations.json"
                $existingSolution = $null
                $existingPackagePath = $null
                if (Test-Path $existingJsonPath) {
                    try {
                        $existingReg = Read-RegistrationJson -Path $existingJsonPath
                        if ($existingReg -and $existingReg.assemblies) {
                            $existingAsm = $existingReg.assemblies | Where-Object { $_.name -eq $proj.Name } | Select-Object -First 1
                            if ($existingAsm) {
                                $existingSolution = $existingAsm.solution
                                $existingPackagePath = $existingAsm.packagePath
                            }
                        }
                    } catch {
                        Write-LogDebug "  Could not read existing registrations.json"
                    }
                }

                $assemblyReg = [PSCustomObject]@{
                    name = $proj.Name
                    type = $proj.Type
                    solution = $existingSolution
                    path = $proj.RelativeDllPath
                    allTypeNames = $allTypeNames
                    plugins = $plugins
                }

                $packagePath = if ($proj.RelativeNupkgPath) { $proj.RelativeNupkgPath } else { $existingPackagePath }
                if ($proj.Type -eq "Nuget" -and $packagePath) {
                    $assemblyReg | Add-Member -MemberType NoteProperty -Name "packagePath" -Value $packagePath
                }

                $registrationJson = ConvertTo-RegistrationJson -Assemblies @($assemblyReg)

                $jsonOutputPath = if ($OutputPath) { $OutputPath } else { Join-Path $proj.ProjectDir "registrations.json" }

                [System.IO.File]::WriteAllText($jsonOutputPath, $registrationJson, [System.Text.UTF8Encoding]::new($false))
                Write-LogSuccess "  Generated: $jsonOutputPath"

                $allResults += $assemblyReg
                $successCount++
            }
            catch {
                Write-LogError "  Failed to extract: $($_.Exception.Message)"
                $errorCount++
            }
        }

        Write-Log ""
        Write-Log ("=" * 60)
        Write-Log "Extraction Summary"
        Write-Log ("=" * 60)
        Write-Log "Projects processed: $($projects.Count)"
        Write-LogSuccess "Successful: $successCount"
        if ($errorCount -gt 0) {
            Write-LogError "Failed: $errorCount"
        }

        return $allResults
    }
    finally {
        Pop-Location
    }
}
