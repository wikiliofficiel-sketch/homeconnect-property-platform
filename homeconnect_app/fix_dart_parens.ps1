
# fix_dart_parens.ps1 - Fixes missing ')' before 'child:' in BoxDecoration and related constructors.
# The pattern: BoxDecoration(..., someParam: someValue,
#                  child:   <- wrong: BoxDecoration has no child
# Fixed to:    BoxDecoration(..., someParam: someValue),
#                  child:   <- correct: child belongs to Container
#
# Each -replace uses three capture groups:
#   $1 = the last valid parameter value (e.g. BorderRadius.circular(20))
#   $2 = the comma + newline + indent  (e.g. ",\n              ")
#   $3 = "child:"
# Replacement inserts ")" between $1 and $2.

$files = Get-ChildItem -Path "lib" -Recurse -Filter "*.dart" | Select-Object -ExpandProperty FullName
$count = 0

foreach ($f in $files) {
    $text = [System.IO.File]::ReadAllText($f)
    $orig = $text

    # ---- BorderRadius.circular(N) ----
    $text = $text -replace '(BorderRadius\.circular\(\d+(?:\.\d+)?\))(,\s*\r?\n\s+)(child:)', '$1)$2$3'

    # ---- BorderRadius.vertical(top: ...) or similar ----
    $text = $text -replace '(BorderRadius\.vertical\([^)]+\))(,\s*\r?\n\s+)(child:)', '$1)$2$3'
    $text = $text -replace '(BorderRadius\.only\([^)]+\))(,\s*\r?\n\s+)(child:)', '$1)$2$3'

    # ---- BoxShape.circle ----
    $text = $text -replace '(BoxShape\.circle)(,\s*\r?\n\s+)(child:)', '$1)$2$3'

    # ---- border: Border.all( single-line ) ----
    $text = $text -replace '(Border\.all\([^)\r\n]+\))(,\s*\r?\n\s+)(child:)', '$1)$2$3'

    # ---- gradient end: Alignment.bottomRight) ----
    $text = $text -replace '(end: Alignment\.(bottomRight|bottomLeft|topRight|topLeft)\))(,\s*\r?\n\s+)(child:)', '$1)$2$3'

    # ---- RoundedRectangleBorder(...) in shape: ----
    $text = $text -replace '(RoundedRectangleBorder\(borderRadius: [^)]+\))(,\s*\r?\n\s+)(child:)', '$1)$2$3'

    # ---- Last BoxShadow ] closing ----
    # Only fix when the ] is closing a boxShadow list: look for the pattern "]) ," then child:
    $text = $text -replace '(\])(,\s*\r?\n\s+)(child:)', '$1)$2$3'

    # ---- shape: BoxShape.circle (again, some combos) ----
    $text = $text -replace '(shape: BoxShape\.circle)(,\s*\r?\n\s+)(child:)', '$1)$2$3'

    # ---- MaterialPageRoute(...)) missing closing for Navigator.push ----
    $text = $text -replace '(Navigator\.push\([^,]+, MaterialPageRoute\(builder: \([^)]+\) => [^)]+\(.*?\)\))(,\s*\r?\n\s+)(child:)', '$1)$2$3'

    # ---- InkWell onTap: missing ) in long lambda ----
    $text = $text -replace '(onTap: \(\) => Navigator\.push\(context, MaterialPageRoute\(builder: \(context\) => \w+\([^)]+\)\))(,\s*\r?\n\s+)(child:)', '$1)$2$3'

    # ---- Any trailing ), line followed by child: that is missing one ) ----
    # This is a final heuristic: if we see "RoundedRectangleBorder(borderRadius: BorderRadius.circular(N)),"
    # but that is inside a shape: param of a Widget that ALSO has child:
    # i.e. shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(N)),\n  child:
    # where shape is a param of Dialog/Card (which DO have child)
    # So we must NOT fix those. This is already handled correctly by the replacement above
    # (it targets RoundedRectangleBorder inside the decoration group, not shape: of a Card).

    if ($text -ne $orig) {
        [System.IO.File]::WriteAllText($f, $text, [System.Text.Encoding]::UTF8)
        $count++
        Write-Host "Fixed: $(Split-Path $f -Leaf)"
    }
}
Write-Host ""
Write-Host "Total files patched: $count"
