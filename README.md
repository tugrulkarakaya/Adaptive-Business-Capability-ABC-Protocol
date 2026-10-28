openssl enc -d -aes-256-cbc -pbkdf2 -iter 200000 -md sha256 -a -in ~/Downloads/icms-parent-links-fix-20261028.txt -out ~/Downloads/icms-parent-links-fix.tar.gz -pass stdin

tar -xzf ~/Downloads/icms-parent-links-fix.tar.gz -C .
