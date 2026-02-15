$path = "d:\untitled\Essenmelia\Flutter-New\lib\l10n\app_en.arb"
$lines = Get-Content $path
$newLines = @()
$seenKeys = @{}
$seenMetadata = @{}
$skipping = $false

# Keep the first line {
$newLines += $lines[0]

for ($i = 1; $i -lt $lines.Count - 1; $i++) {
    $line = $lines[$i]
    # Match a key like "key": or "@key":
    if ($line -match '^\s+"(?<fullKey>(?<prefix>@?)(?<baseKey>[^"]+))":') {
        $fullKey = $Matches['fullKey']
        $prefix = $Matches['prefix']
        $baseKey = $Matches['baseKey']
        
        if ($prefix -eq "@") {
            if ($seenMetadata.ContainsKey($baseKey)) {
                $skipping = $true
            } else {
                $seenMetadata[$baseKey] = $true
                $skipping = $false
                $newLines += $line
            }
        } else {
            if ($seenKeys.ContainsKey($baseKey)) {
                $skipping = $true
            } else {
                $seenKeys[$baseKey] = $true
                $skipping = $false
                $newLines += $line
            }
        }
    } else {
        if (!$skipping) {
            $newLines += $line
        }
    }
}

# Keep the last line }
$newLines += $lines[-1]

$newLines | Set-Content "d:\untitled\Essenmelia\Flutter-New\lib\l10n\app_en.arb.fixed"
