
# fix_dart_parens2.ps1 - Round 2: Reverts over-fixes and repairs remaining real errors

$files = Get-ChildItem -Path "lib" -Recurse -Filter "*.dart" | Select-Object -ExpandProperty FullName
$count = 0

foreach ($f in $files) {
    $text = [System.IO.File]::ReadAllText($f)
    $orig = $text

    # =====================================================================
    # REVERTS: widgets that legitimately accept borderRadius AND child:
    # InkWell, ClipRRect, ClipOval, GestureDetector + borderRadius param
    # The automation added an extra ) here - revert it.
    # Pattern: borderRadius: BorderRadius.circular(N)), <newline> child:
    # where the )) is wrong (should be just one ) closing BorderRadius.circular)
    # We detect these by checking that the SAME line also has something like
    # InkWell or ClipRRect earlier in the widget context.
    # Simpler: ANY case where borderRadius: is a NAMED PARAM at the TOP LEVEL of a widget
    # (not inside decoration: BoxDecoration(...)), we should NOT add an extra ).
    #
    # Heuristic: if the previous non-empty line ends with a comma or is "onTap: ...",
    # it's a widget param, not a BoxDecoration param.
    # REVERT: borderRadius: BorderRadius.circular(N)), <newline> child:
    #      -> borderRadius: BorderRadius.circular(N),  <newline> child:
    # ONLY when this borderRadius is a direct widget param (InkWell, ClipRRect, etc.)
    # =====================================================================

    # Revert: onTap line before borderRadius means it's InkWell
    $text = $text -replace '(onTap: [^\n]+,\r?\n\s+borderRadius: BorderRadius\.circular\(\d+(?:\.\d+)?\))\)(,\r?\n)', '$1$2'

    # Revert: ClipRRect( immediately before borderRadius line
    $text = $text -replace '(ClipRRect\(\r?\n\s+borderRadius: BorderRadius\.circular\(\d+(?:\.\d+)?\))\)(,\r?\n)', '$1$2'

    # Revert: borderRadius is a top-level widget param with ) at end but no BoxDecoration context
    # More general: if a line is ONLY "borderRadius: BorderRadius.circular(N))," (extra ))
    # and NOT inside a BoxDecoration, revert.
    # We use the sign: decorations have "decoration: BoxDecoration(" somewhere above,
    # but since that's complex, we use: GlassContainer, InkWell, ClipRRect patterns
    $text = $text -replace '(GlassContainer\([^\n]*\r?\n\s+[^\n]+\r?\n\s+borderRadius: BorderRadius\.circular\(\d+(?:\.\d+)?\))\)(,\r?\n)', '$1$2'

    # =====================================================================
    # FIX: const BorderRadius.vertical(top: Radius.circular(N)) inside BoxDecoration
    # The original script missed this because [^)]+ can't match nested parens.
    # Pattern:  borderRadius: const BorderRadius.vertical(top: Radius.circular(N))),
    #                child:
    # Already should have TWO closing )) for vertical+circular, we add a THIRD for BoxDecoration
    # But first check: if it has only ONE ) at the end (meaning BoxDecoration still open)
    # =====================================================================

    # Fix const BorderRadius.vertical(...)) missing BoxDecoration close
    # The broken text: "borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),"
    # followed by "child:" - needs one more ) to close BoxDecoration
    $text = $text -replace '(borderRadius: (?:const )?BorderRadius\.vertical\((?:top|bottom): (?:const )?Radius\.circular\(\d+\)\))(,\s*\r?\n\s+)(child:)', '$1)$2$3'

    # =====================================================================
    # FIX: setState arrow closures with extra ) 
    # setState(() => x = val)); -> setState(() => x = val);
    # =====================================================================
    $text = $text -replace 'setState\(\(\) => ([^;)]+)\)\);', 'setState(() => $1);'

    # =====================================================================
    # FIX: Admin dashboard InkWell onTap extra ))
    # onTap: () => Navigator.push(...)))), -> onTap: () => Navigator.push(...)),
    # =====================================================================
    $text = $text -replace '(onTap: \(\) => Navigator\.push\(context, MaterialPageRoute\(builder: \(context\) => \w+\([^)]+\)\)\))\)(,\s*\r?\n)', '$1$2'

    # =====================================================================
    # FIX: TabBar onTap setState extra )
    # onTap: (index) => setState(() => _selectedIndex = index)),
    # ->  onTap: (index) => setState(() => _selectedIndex = index),
    # =====================================================================
    $text = $text -replace '(onTap: \(index\) => setState\(\(\) => \w+ = index\))\)(,\s*\r?\n)', '$1$2'

    # =====================================================================
    # FIX: Padding widget written as just ( without class name
    # Replace lone "                (" at indented level that has padding: on next line
    # This is a pre-existing bug: "Padding(" was written as just "("
    # =====================================================================
    $text = $text -replace '(\r?\n(\s+))\(\r?\n(\s+)(padding: EdgeInsets)', '$1Padding($3$4'

    if ($text -ne $orig) {
        [System.IO.File]::WriteAllText($f, $text, [System.Text.Encoding]::UTF8)
        $count++
        Write-Host "Fixed: $(Split-Path $f -Leaf)"
    }
}
Write-Host ""
Write-Host "Files patched: $count"
