$files = Get-ChildItem -Recurse -Filter *.dart
foreach ($f in $files) {
    Write-Host "Convertendo: $($f.FullName)"
    $bytes = [System.IO.File]::ReadAllBytes($f.FullName)
    $text = [System.Text.Encoding]::GetEncoding(1252).GetString($bytes)
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($f.FullName, $text, $utf8)
    Write-Host "OK"
}
Write-Host "FINALIZADO"
