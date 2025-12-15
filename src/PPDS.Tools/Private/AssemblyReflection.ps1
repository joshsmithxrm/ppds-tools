function Invoke-WithAssemblyResolution {
    <#
    .SYNOPSIS
        Executes a script block with assembly resolution handling.
    .DESCRIPTION
        Loads a .NET assembly with proper dependency resolution. Dependencies
        are resolved from the same directory as the main DLL.
    .PARAMETER DllPath
        Path to the DLL to load.
    .PARAMETER ScriptBlock
        Script block to execute with the loaded assembly. Receives the assembly
        as a parameter.
    .OUTPUTS
        The result of the script block execution.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$DllPath,

        [Parameter(Mandatory = $true)]
        [scriptblock]$ScriptBlock
    )

    if (-not (Test-Path $DllPath)) {
        throw "DLL not found: $DllPath"
    }

    $dllFullPath = (Resolve-Path $DllPath).Path
    $dllDir = Split-Path $dllFullPath -Parent

    # Create handler to resolve dependencies from the same directory
    $resolveHandler = [System.ResolveEventHandler]{
        param($s, $e)
        $assemblyName = (New-Object System.Reflection.AssemblyName($e.Name)).Name
        $localDllPath = Join-Path $dllDir "$assemblyName.dll"
        if (Test-Path $localDllPath) {
            return [System.Reflection.Assembly]::LoadFrom($localDllPath)
        }
        return $null
    }

    [System.AppDomain]::CurrentDomain.add_AssemblyResolve($resolveHandler)

    try {
        $assembly = [System.Reflection.Assembly]::LoadFrom($dllFullPath)
        return & $ScriptBlock $assembly
    }
    finally {
        [System.AppDomain]::CurrentDomain.remove_AssemblyResolve($resolveHandler)
    }
}

function Get-PluginRegistrationsFromAssembly {
    <#
    .SYNOPSIS
        Extracts plugin registrations from a compiled assembly using reflection.
    .PARAMETER DllPath
        Path to the compiled plugin DLL.
    .OUTPUTS
        Array of plugin registration objects.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$DllPath
    )

    return Invoke-WithAssemblyResolution -DllPath $DllPath -ScriptBlock {
        param($assembly)
        $plugins = @()

        foreach ($type in $assembly.GetExportedTypes()) {
            if ($type.IsAbstract -or $type.IsInterface) {
                continue
            }

            $stepAttributes = $type.GetCustomAttributes($true) | Where-Object {
                $_.GetType().Name -eq "PluginStepAttribute"
            }

            if ($stepAttributes.Count -eq 0) {
                continue
            }

            $imageAttributes = $type.GetCustomAttributes($true) | Where-Object {
                $_.GetType().Name -eq "PluginImageAttribute"
            }

            $steps = @()
            foreach ($stepAttr in $stepAttributes) {
                $stepId = $stepAttr.StepId
                $stepName = if ($stepAttr.Name) {
                    $stepAttr.Name
                } else {
                    "$($type.FullName): $($stepAttr.Message) of $($stepAttr.EntityLogicalName)"
                }

                $stageValue = [int]$stepAttr.Stage
                $modeValue = [int]$stepAttr.Mode
                $stageName = $script:PluginStageMap[$stageValue]
                $modeName = $script:PluginModeMap[$modeValue]

                $stepImages = @()
                foreach ($imageAttr in $imageAttributes) {
                    $shouldInclude = if ($stepId -and $imageAttr.StepId) {
                        $stepId -eq $imageAttr.StepId
                    } elseif (-not $stepId -and -not $imageAttr.StepId) {
                        $true
                    } elseif ($stepAttributes.Count -eq 1 -and -not $imageAttr.StepId) {
                        $true
                    } else {
                        $false
                    }

                    if ($shouldInclude) {
                        $imageTypeValue = [int]$imageAttr.ImageType
                        $imageTypeName = $script:PluginImageTypeMap[$imageTypeValue]

                        $stepImages += [PSCustomObject]@{
                            name = $imageAttr.Name
                            imageType = $imageTypeName
                            attributes = $imageAttr.Attributes
                            entityAlias = if ($imageAttr.EntityAlias) { $imageAttr.EntityAlias } else { $imageAttr.Name }
                        }
                    }
                }

                $steps += [PSCustomObject]@{
                    name = $stepName
                    message = $stepAttr.Message
                    entity = $stepAttr.EntityLogicalName
                    secondaryEntity = $stepAttr.SecondaryEntityLogicalName
                    stage = $stageName
                    mode = $modeName
                    executionOrder = $stepAttr.ExecutionOrder
                    filteringAttributes = $stepAttr.FilteringAttributes
                    configuration = $stepAttr.UnsecureConfiguration
                    stepId = $stepId
                    images = $stepImages
                }
            }

            $plugins += [PSCustomObject]@{
                typeName = $type.FullName
                steps = $steps
            }
        }

        return $plugins
    }
}

function Get-AllPluginTypeNames {
    <#
    .SYNOPSIS
        Gets all plugin and workflow activity type names from a compiled assembly.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$DllPath
    )

    return Invoke-WithAssemblyResolution -DllPath $DllPath -ScriptBlock {
        param($assembly)
        $typeNames = @()

        foreach ($type in $assembly.GetExportedTypes()) {
            if ($type.IsAbstract -or $type.IsInterface) {
                continue
            }

            $isPlugin = $false

            foreach ($iface in $type.GetInterfaces()) {
                if ($iface.Name -eq "IPlugin" -or $iface.FullName -eq "Microsoft.Xrm.Sdk.IPlugin") {
                    $isPlugin = $true
                    break
                }
            }

            if (-not $isPlugin) {
                $baseType = $type.BaseType
                while ($null -ne $baseType) {
                    if ($baseType.Name -eq "CodeActivity" -or $baseType.FullName -like "*CodeActivity") {
                        $isPlugin = $true
                        break
                    }
                    $baseType = $baseType.BaseType
                }
            }

            if ($isPlugin) {
                $typeNames += $type.FullName
            }
        }

        return $typeNames
    }
}

function Get-PluginProjects {
    <#
    .SYNOPSIS
        Discovers plugin projects in a repository.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepositoryRoot
    )

    $projects = @()

    $classicPath = Join-Path $RepositoryRoot "src/Plugins"
    if (Test-Path $classicPath) {
        Get-ChildItem -Path $classicPath -Filter "*.csproj" -Recurse | ForEach-Object {
            $projectDir = $_.DirectoryName
            $projectName = $_.BaseName

            $dllPath = Join-Path $projectDir "bin/Release/net462/$projectName.dll"
            $debugDllPath = Join-Path $projectDir "bin/Debug/net462/$projectName.dll"

            $actualDllPath = if (Test-Path $dllPath) { $dllPath }
                             elseif (Test-Path $debugDllPath) { $debugDllPath }
                             else { $null }

            $projects += [PSCustomObject]@{
                Name = $projectName
                ProjectPath = $_.FullName
                ProjectDir = $projectDir
                Type = "Assembly"
                DllPath = $actualDllPath
                RelativeDllPath = if ($actualDllPath) {
                    (Resolve-Path -Path $actualDllPath -Relative -ErrorAction SilentlyContinue) -replace '\\','/'
                } else { $null }
            }
        }
    }

    $packagePath = Join-Path $RepositoryRoot "src/PluginPackages"
    if (Test-Path $packagePath) {
        Get-ChildItem -Path $packagePath -Filter "*.csproj" -Recurse | ForEach-Object {
            $projectDir = $_.DirectoryName
            $projectName = $_.BaseName

            $dllPath = Join-Path $projectDir "bin/Release/net462/$projectName.dll"
            $debugDllPath = Join-Path $projectDir "bin/Debug/net462/$projectName.dll"

            $actualDllPath = if (Test-Path $dllPath) { $dllPath }
                             elseif (Test-Path $debugDllPath) { $debugDllPath }
                             else { $null }

            $nupkgPattern = Join-Path $projectDir "bin/Release/*.nupkg"
            $nupkgFile = Get-ChildItem -Path $nupkgPattern -ErrorAction SilentlyContinue |
                         Sort-Object LastWriteTime -Descending |
                         Select-Object -First 1

            $projects += [PSCustomObject]@{
                Name = $projectName
                ProjectPath = $_.FullName
                ProjectDir = $projectDir
                Type = "Nuget"
                DllPath = $actualDllPath
                NupkgPath = $nupkgFile.FullName
                RelativeDllPath = if ($actualDllPath) {
                    (Resolve-Path -Path $actualDllPath -Relative -ErrorAction SilentlyContinue) -replace '\\','/'
                } else { $null }
                RelativeNupkgPath = if ($nupkgFile) {
                    (Resolve-Path -Path $nupkgFile.FullName -Relative -ErrorAction SilentlyContinue) -replace '\\','/'
                } else { $null }
            }
        }
    }

    return $projects
}
