
$f = "z:\logic\docs\architecture\business-architecture.md"
$c = [System.IO.File]::ReadAllText($f, [System.Text.Encoding]::UTF8)
$map = @{
    '1'  = [System.Char]::ConvertFromUtf32(0x1F3C1)
    '2'  = [System.Char]::ConvertFromUtf32(0x1F4A1)
    '3'  = [System.Char]::ConvertFromUtf32(0x1F30A)
    '4'  = [System.Char]::ConvertFromUtf32(0x1F504)
    '5'  = [System.Char]::ConvertFromUtf32(0x1F6E0) + [char]0xFE0F
    '6'  = [System.Char]::ConvertFromUtf32(0x1F9E9)
    '7'  = [System.Char]::ConvertFromUtf32(0x1F464)
    '8'  = [System.Char]::ConvertFromUtf32(0x1F4D0)
    '9'  = [System.Char]::ConvertFromUtf32(0x26A1)
    '10' = [System.Char]::ConvertFromUtf32(0x1F4E6)
    '11' = [System.Char]::ConvertFromUtf32(0x1F4C8)
}
foreach ($sec in $map.Keys) {
    $emoji = $map[$sec]
    $pat = "(?m)^(#### )(5\.$sec\.\d+)"
    $c = [regex]::Replace($c, $pat, "`$1$emoji `$2")
}
[System.IO.File]::WriteAllText($f, $c, [System.Text.Encoding]::UTF8)
Write-Host "Done"


# Keep first $keep pipe-delimited columns of a markdown table row
function Cut-Cols($line, $keep) {
    $count = 0
    for ($c = 0; $c -lt $line.Length; $c++) {
        if ($line[$c] -eq '|') {
            $count++
            if ($count -eq $keep + 1) { return $line.Substring(0, $c) + ' |' }
        }
    }
    return $line
}

$result = [System.Collections.Generic.List[string]]::new()
$i = 0

while ($i -lt $lines.Length) {
    $line = $lines[$i]

    # ── Remove **Source** / **Confidence** / **Maturity** spec rows ────────────
    if ($line -match '^\| \*\*Source\*\*\s+\|' -or
        $line -match '^\| \*\*Confidence\*\*\s+\|' -or
        $line -match '^\| \*\*Maturity\*\*\s+\|') {
        $i++; continue
    }

    # ── Section 2.7–2.11: strip to 2 cols + emoji header ─────────────────────
    $sec2 = @{
        '### 2.7' = '👤'; '### 2.8' = '📐'; '### 2.9' = '⚡'
        '### 2.10' = '📦'; '### 2.11' = '📈'
    }
    $matched = $null
    foreach ($k in $sec2.Keys) { if ($line.StartsWith($k)) { $matched = $sec2[$k]; break } }

    if ($matched) {
        $result.Add($line); $i++
        # blank lines before table
        while ($i -lt $lines.Length -and $lines[$i].Trim() -eq '') { $result.Add($lines[$i]); $i++ }
        # header row
        if ($i -lt $lines.Length -and $lines[$i] -match '^\| Name') {
            $hdr = Cut-Cols $lines[$i] 2
            $hdr = [regex]::Replace($hdr, '\| Name\s+\|', "| $matched Name |")
            $hdr = [regex]::Replace($hdr, '\| Description\s+\|', '| 💬 Description |')
            $result.Add($hdr); $i++
            # separator
            if ($i -lt $lines.Length -and $lines[$i] -match '^\| -') { $result.Add((Cut-Cols $lines[$i] 2)); $i++ }
            # data rows
            while ($i -lt $lines.Length -and $lines[$i] -match '^\|') { $result.Add((Cut-Cols $lines[$i] 2)); $i++ }
        }
        continue
    }

    # ── Section 4: Capability Maturity table (3→2 cols) ─────────────────────
    if ($line -match '^\*\*Current State: Capability Maturity Summary\*\*') {
        $result.Add($line); $i++
        while ($i -lt $lines.Length -and $lines[$i].Trim() -eq '') { $result.Add($lines[$i]); $i++ }
        if ($i -lt $lines.Length -and $lines[$i] -match '^\| Capability') {
            $result.Add('| 💡 Capability | 📊 Maturity Level |'); $i++
            if ($i -lt $lines.Length -and $lines[$i] -match '^\| -') { $result.Add((Cut-Cols $lines[$i] 2)); $i++ }
            while ($i -lt $lines.Length -and $lines[$i] -match '^\|') { $result.Add((Cut-Cols $lines[$i] 2)); $i++ }
        }
        continue
    }

    # ── Section 4: Workflow Patterns table (3→2 cols) ────────────────────────
    if ($line -match '^\*\*Workflow Patterns\*\*') {
        $result.Add($line); $i++
        while ($i -lt $lines.Length -and $lines[$i].Trim() -eq '') { $result.Add($lines[$i]); $i++ }
        if ($i -lt $lines.Length -and $lines[$i] -match '^\| Pattern') {
            $result.Add('| 🔄 Pattern | ⚙️ Implementation |'); $i++
            if ($i -lt $lines.Length -and $lines[$i] -match '^\| -') { $result.Add((Cut-Cols $lines[$i] 2)); $i++ }
            while ($i -lt $lines.Length -and $lines[$i] -match '^\|') { $result.Add((Cut-Cols $lines[$i] 2)); $i++ }
        }
        continue
    }

    # ── Section 8: Business-to-Application (5→4 cols) ────────────────────────
    if ($line -eq '### Business-to-Application Layer Dependencies') {
        $result.Add('### 🏗️ Business-to-Application Layer Dependencies'); $i++
        while ($i -lt $lines.Length -and $lines[$i].Trim() -eq '') { $result.Add($lines[$i]); $i++ }
        if ($i -lt $lines.Length -and $lines[$i] -match '^\| Business Component') {
            $result.Add('| 🏢 Business Component | 🖥️ Application Component | 🔌 Integration Protocol | 🔗 Coupling |'); $i++
            if ($i -lt $lines.Length -and $lines[$i] -match '^\| -') { $result.Add((Cut-Cols $lines[$i] 4)); $i++ }
            while ($i -lt $lines.Length -and $lines[$i] -match '^\|') { $result.Add((Cut-Cols $lines[$i] 4)); $i++ }
        }
        continue
    }

    # ── Section 8: Business-to-Data (5→4 cols) ───────────────────────────────
    if ($line -eq '### Business-to-Data Layer Dependencies') {
        $result.Add('### 🗄️ Business-to-Data Layer Dependencies'); $i++
        while ($i -lt $lines.Length -and $lines[$i].Trim() -eq '') { $result.Add($lines[$i]); $i++ }
        if ($i -lt $lines.Length -and $lines[$i] -match '^\| Business Component') {
            $result.Add('| 🏢 Business Component | 🗃️ Data Component | 🔌 Integration Protocol | 📖 Access Pattern |'); $i++
            if ($i -lt $lines.Length -and $lines[$i] -match '^\| -') { $result.Add((Cut-Cols $lines[$i] 4)); $i++ }
            while ($i -lt $lines.Length -and $lines[$i] -match '^\|') { $result.Add((Cut-Cols $lines[$i] 4)); $i++ }
        }
        continue
    }

    # ── Section 8: Business-to-Observability (5→4 cols) ─────────────────────
    if ($line -eq '### Business-to-Observability Layer Dependencies') {
        $result.Add('### 👁️ Business-to-Observability Layer Dependencies'); $i++
        while ($i -lt $lines.Length -and $lines[$i].Trim() -eq '') { $result.Add($lines[$i]); $i++ }
        if ($i -lt $lines.Length -and $lines[$i] -match '^\| Business Component') {
            $result.Add('| 🏢 Business Component | 📡 Observability Channel | 📊 Telemetry Type | 📏 Metric / Trace Name |'); $i++
            if ($i -lt $lines.Length -and $lines[$i] -match '^\| -') { $result.Add((Cut-Cols $lines[$i] 4)); $i++ }
            while ($i -lt $lines.Length -and $lines[$i] -match '^\|') { $result.Add((Cut-Cols $lines[$i] 4)); $i++ }
        }
        continue
    }

    # ── Section 5: Attribute/Value spec table header ──────────────────────────
    if ($line -match '^\| Attribute\s+\| Value\s+\|') {
        $result.Add('| 🔑 Attribute | 📋 Value |'); $i++
        continue
    }
    if ($line -match '^\| ---+\s*\| ---+\s*\|' -and $i -gt 0 -and $result[$result.Count - 1] -match '^\| 🔑 Attribute') {
        # separator after our new header — keep as-is
        $result.Add($line); $i++; continue
    }

    $result.Add($line)
    $i++
}

[System.IO.File]::WriteAllLines($file, $result, [System.Text.Encoding]::UTF8)
Write-Host "Done. Lines written: $($result.Count)"
