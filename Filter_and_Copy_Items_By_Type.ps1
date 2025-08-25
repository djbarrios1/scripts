$src = "C:\Path\To\Source"
$dst = "C:\Path\To\Destination"
New-Item -ItemType Directory -Force -Path $dst | Out-Null

Get-ChildItem -Path $src -Recurse -Filter *.eml | ForEach-Object {
    $name = $_.Name
    $base = [IO.Path]::GetFileNameWithoutExtension($name)
    $ext  = $_.Extension
    $target = Join-Path $dst $name
    $i = 1
    while (Test-Path -LiteralPath $target) {
        $target = Join-Path $dst ("{0}_{1}{2}" -f $base, $i, $ext)
        $i++
    }
    Copy-Item -LiteralPath $_.FullName -Destination $target
}
