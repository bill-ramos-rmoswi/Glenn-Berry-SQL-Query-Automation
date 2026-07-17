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

Export-ModuleMember -Function Get-DiagnosticQueryBlocks
