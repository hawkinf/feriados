
Write-Host "Convertendo arquivos .dart para UTF-8..."
$dartFiles = Get-ChildItem -Recurse -Filter *.dart
foreach ($file in $dartFiles) {
    Write-Host "Convertendo: $($file.FullName)"
    $content = Get-Content -Path $file.FullName -Raw
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($file.FullName, $content, $utf8)
    Write-Host "OK"
}
Write-Host "Finalizado!"
