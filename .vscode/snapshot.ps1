# Snapshot só se houver mudanças + tag snapshot-latest
$d = Get-Date -Format "yyyy-MM-dd_HH-mm"

git add -A | Out-Null

$hasChanges = (git diff --cached --name-only)
if ([string]::IsNullOrWhiteSpace($hasChanges)) {
  Write-Host "Nenhuma alteração detectada. Snapshot não foi criado."
  exit 0
}

git commit -m "Snapshot ($d)"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

git push
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

# Tag única por snapshot
git tag -a "snapshot-$d" -m "Snapshot $d"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
git push origin "snapshot-$d"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

# Tag "latest" que sempre aponta pro último snapshot
git tag -f -a "snapshot-latest" -m "Último snapshot: $d"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

git push origin -f "snapshot-latest"
exit $LASTEXITCODE
