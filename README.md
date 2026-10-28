

tar -xzf ~/Downloads/icms-parent-links-fix.tar.gz -C .


Password: p9h7j4Q-pdDvBKnxOWUcxgvWV5dxrEpqI7Vb



$src = "$env:USERPROFILE\Downloads\icms-parent-links-fix-20261028.txt"
$dst = "$env:USERPROFILE\Downloads\icms-parent-links-fix.tar.gz"
$data = [Convert]::FromBase64String([IO.File]::ReadAllText($src))
if ([Text.Encoding]::ASCII.GetString($data, 0, 8) -ne 'Salted__') { throw "Invalid encrypted file" }
$salt = New-Object byte[] 8
[Array]::Copy($data, 8, $salt, 0, 8)

$secure = Read-Host "Enter the package password" -AsSecureString
$ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
try {
    $password = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
    $kdf = [Security.Cryptography.Rfc2898DeriveBytes]::new($password, $salt, 200000, [Security.Cryptography.HashAlgorithmName]::SHA256)
    $aes = [Security.Cryptography.Aes]::Create()
    $aes.Key = $kdf.GetBytes(32)
    $aes.IV = $kdf.GetBytes(16)
    $plain = $aes.CreateDecryptor().TransformFinalBlock($data, 16, $data.Length - 16)
    [IO.File]::WriteAllBytes($dst, $plain)
    Write-Host "Decrypted: $dst"
} finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
    Remove-Variable password -ErrorAction SilentlyContinue
}
