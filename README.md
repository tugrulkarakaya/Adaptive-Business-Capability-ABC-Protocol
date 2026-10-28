openssl enc -d -aes-256-cbc -pbkdf2 -iter 200000 -md sha256 -a -in ~/Downloads/icms-parent-links-fix-20261028.txt -out ~/Downloads/icms-parent-links-fix.tar.gz -pass stdin

tar -xzf ~/Downloads/icms-parent-links-fix.tar.gz -C .


$ssl = Get-ChildItem "$env:ProgramFiles\Git" -Filter openssl.exe -Recurse -File -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
$ssl

Password: p9h7j4Q-pdDvBKnxOWUcxgvWV5dxrEpqI7Vb
