$d = Get-Date -Format "yyyy-MM-dd_HH-mm"

git add -A
git commit --allow-empty -m "Snapshot ($d)"
git push

git tag -a "snapshot-$d" -m "Snapshot $d"
git push origin "snapshot-$d"
