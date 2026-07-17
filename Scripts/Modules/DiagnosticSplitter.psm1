function Get-DiagnosticQueryBlocks {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [AllowEmptyCollection()]
        [string[]]$Lines
    )

    $headerPattern = '^--\s*(?<desc>.+?)\s*\(Query\s+(?<num>\d+)\)\s*\((?<short>[^)]+)\)\s*$'

    $blocks = [System.Collections.Generic.List[pscustomobject]]::new()
    $currentScope = 'Instance'
    $current = $null
    $buffer = [System.Collections.Generic.List[string]]::new()

    foreach ($line in $Lines) {
        if ($line -match 'Instance level queries') {
            $currentScope = 'Instance'
            continue
        }
        if ($line -match 'Database specific queries') {
            $currentScope = 'Database'
            continue
        }

        $headerMatch = [regex]::Match($line, $headerPattern)
        if ($headerMatch.Success) {
            if ($null -ne $current) {
                while ($buffer.Count -gt 0 -and [string]::IsNullOrWhiteSpace($buffer[$buffer.Count - 1])) {
                    $buffer.RemoveAt($buffer.Count - 1)
                }
                $current.Content = ($buffer -join [Environment]::NewLine)
                $blocks.Add($current)
            }

            $buffer = [System.Collections.Generic.List[string]]::new()
            $buffer.Add($line)
            $current = [pscustomobject]@{
                Number      = [int]$headerMatch.Groups['num'].Value
                ShortName   = $headerMatch.Groups['short'].Value.Trim()
                Description = $headerMatch.Groups['desc'].Value.Trim()
                Scope       = $currentScope
                Content     = ''
            }
            continue
        }

        if ($null -ne $current) {
            $buffer.Add($line)
        }
    }

    if ($null -ne $current) {
        while ($buffer.Count -gt 0 -and [string]::IsNullOrWhiteSpace($buffer[$buffer.Count - 1])) {
            $buffer.RemoveAt($buffer.Count - 1)
        }
        $current.Content = ($buffer -join [Environment]::NewLine)
        $blocks.Add($current)
    }

    return $blocks.ToArray()
}

function Split-DiagnosticQueryFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SourcePath,

        [Parameter(Mandatory)]
        [string]$OutputRoot
    )

    $sourceLines = Get-Content -LiteralPath $SourcePath
    $sourceText = $sourceLines -join [Environment]::NewLine

    $copyrightMatch = [regex]::Match($sourceText, '(?s)--\*{10,}.*?Copyright.*?--\*{10,}')
    if (-not $copyrightMatch.Success) {
        throw "Could not find Copyright block in '$SourcePath'"
    }
    $copyrightBlock = $copyrightMatch.Value

    $versionFolderName = ([System.IO.Path]::GetFileNameWithoutExtension($SourcePath)) -replace '\s+Diagnostic Information Queries$', ''

    $blocks = Get-DiagnosticQueryBlocks -Lines $sourceLines

    $versionRoot = Join-Path $OutputRoot $versionFolderName
    $instanceDir = Join-Path $versionRoot 'Instance'
    $databaseDir = Join-Path $versionRoot 'Database'

    if (Test-Path -LiteralPath $versionRoot) {
        Remove-Item -LiteralPath $versionRoot -Recurse -Force
    }
    New-Item -ItemType Directory -Path $instanceDir -Force | Out-Null
    New-Item -ItemType Directory -Path $databaseDir -Force | Out-Null

    $invalidChars = [regex]::Escape(([System.IO.Path]::GetInvalidFileNameChars() -join ''))
    $manifest = [System.Collections.Generic.List[pscustomobject]]::new()

    foreach ($block in $blocks) {
        $safeShortName = $block.ShortName -replace "[$invalidChars]", '-'
        $fileName = 'Query{0:D2}-{1}.sql' -f $block.Number, $safeShortName
        $scopeDirName = $block.Scope
        $targetDir = if ($block.Scope -eq 'Instance') { $instanceDir } else { $databaseDir }
        $filePath = Join-Path $targetDir $fileName

        $fileContent = $copyrightBlock + [Environment]::NewLine + [Environment]::NewLine + $block.Content
        Set-Content -LiteralPath $filePath -Value $fileContent -Encoding UTF8

        $manifest.Add([pscustomobject]@{
            Number    = $block.Number
            ShortName = $block.ShortName
            Scope     = $block.Scope
            File      = "$scopeDirName/$fileName"
        })
    }

    $manifestPath = Join-Path $versionRoot 'manifest.json'
    ($manifest | Sort-Object Number) | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath $manifestPath -Encoding UTF8

    return [pscustomobject]@{
        VersionFolder = $versionFolderName
        InstanceCount = @($manifest | Where-Object Scope -eq 'Instance').Count
        DatabaseCount = @($manifest | Where-Object Scope -eq 'Database').Count
        ManifestPath  = $manifestPath
    }
}

Export-ModuleMember -Function Get-DiagnosticQueryBlocks, Split-DiagnosticQueryFile
