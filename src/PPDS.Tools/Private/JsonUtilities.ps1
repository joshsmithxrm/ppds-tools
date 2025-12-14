function ConvertTo-RegistrationJson {
    <#
    .SYNOPSIS
        Converts plugin registration objects to JSON format.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [array]$Assemblies,
        [Parameter()]
        [string]$SchemaRelativePath = "../../../tools/schemas/plugin-registration.schema.json"
    )

    function Format-JsonValue {
        param($value, [int]$indent = 0)
        $indentStr = "  " * $indent

        if ($null -eq $value) {
            return "null"
        }
        elseif ($value -is [bool]) {
            return $value.ToString().ToLower()
        }
        elseif ($value -is [int] -or $value -is [long] -or $value -is [double]) {
            return $value.ToString()
        }
        elseif ($value -is [string]) {
            $escaped = $value -replace '\\', '\\' -replace '"', '\"' -replace "`n", '\n' -replace "`r", '\r' -replace "`t", '\t'
            return "`"$escaped`""
        }
        elseif ($value -is [array] -or ($value -is [System.Collections.IEnumerable] -and $value -isnot [string] -and $value -isnot [hashtable] -and $value -isnot [PSCustomObject])) {
            $items = @($value)
            if ($items.Count -eq 0) {
                return "[]"
            }
            $innerIndent = "  " * ($indent + 1)
            $elements = @()
            foreach ($item in $items) {
                $elements += "$innerIndent$(Format-JsonValue $item ($indent + 1))"
            }
            return "[$([Environment]::NewLine)$($elements -join ",$([Environment]::NewLine)")$([Environment]::NewLine)$indentStr]"
        }
        elseif ($value -is [PSCustomObject]) {
            $props = $value.PSObject.Properties
            if ($props.Count -eq 0) {
                return "{}"
            }
            $innerIndent = "  " * ($indent + 1)
            $members = @()
            foreach ($prop in $props) {
                $members += "$innerIndent`"$($prop.Name)`": $(Format-JsonValue $prop.Value ($indent + 1))"
            }
            return "{$([Environment]::NewLine)$($members -join ",$([Environment]::NewLine)")$([Environment]::NewLine)$indentStr}"
        }
        elseif ($value -is [hashtable]) {
            if ($value.Count -eq 0) {
                return "{}"
            }
            $innerIndent = "  " * ($indent + 1)
            $members = @()
            foreach ($key in $value.Keys) {
                $members += "$innerIndent`"$key`": $(Format-JsonValue $value[$key] ($indent + 1))"
            }
            return "{$([Environment]::NewLine)$($members -join ",$([Environment]::NewLine)")$([Environment]::NewLine)$indentStr}"
        }
        else {
            return "`"$($value.ToString())`""
        }
    }

    $registration = [PSCustomObject][ordered]@{
        '$schema' = $SchemaRelativePath
        version = "1.0"
        generatedAt = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        assemblies = @($Assemblies | ForEach-Object {
            $asm = $_
            $asmObj = [PSCustomObject][ordered]@{
                name = $asm.name
                type = $asm.type
                solution = $asm.solution
                path = $asm.path
                plugins = @($asm.plugins | ForEach-Object {
                    $plugin = $_
                    [PSCustomObject][ordered]@{
                        typeName = $plugin.typeName
                        steps = @($plugin.steps | ForEach-Object {
                            $step = $_
                            [PSCustomObject][ordered]@{
                                name = $step.name
                                message = $step.message
                                entity = $step.entity
                                stage = $step.stage
                                mode = $step.mode
                                executionOrder = $step.executionOrder
                                filteringAttributes = $step.filteringAttributes
                                configuration = $step.configuration
                                images = @($step.images | ForEach-Object {
                                    $img = $_
                                    [PSCustomObject][ordered]@{
                                        name = $img.name
                                        imageType = $img.imageType
                                        attributes = $img.attributes
                                        entityAlias = $img.entityAlias
                                    }
                                })
                            }
                        })
                    }
                })
            }
            if ($asm.allTypeNames -and $asm.allTypeNames.Count -gt 0) {
                $asmObj | Add-Member -MemberType NoteProperty -Name "allTypeNames" -Value ([array]$asm.allTypeNames)
            }
            if ($asm.type -eq "Nuget" -and $asm.packagePath) {
                $asmObj | Add-Member -MemberType NoteProperty -Name "packagePath" -Value $asm.packagePath
            }
            $asmObj
        })
    }

    return Format-JsonValue $registration 0
}

function Read-RegistrationJson {
    <#
    .SYNOPSIS
        Reads a registrations.json file.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        return $null
    }

    $content = Get-Content $Path -Raw
    return $content | ConvertFrom-Json
}
