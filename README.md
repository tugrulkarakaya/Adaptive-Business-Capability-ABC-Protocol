
$src = "$env:USERPROFILE\Downloads\icms-parent-links-fix-plain-base64.txt"
$archive = "$env:USERPROFILE\Downloads\icms-parent-links-fix.tar.gz"
[IO.File]::WriteAllBytes($archive, [Convert]::FromBase64String([IO.File]::ReadAllText($src)))

tar -xzf $archive -C .
