param(
    [string]$EncryptedFile = (Join-Path $env:USERPROFILE 'Downloads/file23.txt'),
    [string]$OutputDirectory = (Join-Path $env:TEMP ('icms-15364-scope-' + (Get-Date -Format 'yyyyMMdd-HHmmss')))
)
$ErrorActionPreference = 'Stop'
$envelope = Get-Content $EncryptedFile -Raw | ConvertFrom-Json
if ($envelope.format -ne 'ICMS15' -or $envelope.iterations -ne 200000) { throw 'Unexpected encrypted file format.' }
$secure = Read-Host 'Transfer password' -AsSecureString
$pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
try { $password = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer) }
finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer) }
$salt = [Convert]::FromBase64String($envelope.salt)
$iv = [Convert]::FromBase64String($envelope.iv)
$cipher = [Convert]::FromBase64String($envelope.ciphertext)
$tag = [Convert]::FromBase64String($envelope.tag)
if ($salt.Length -ne 16 -or $iv.Length -ne 16 -or $tag.Length -ne 32) { throw 'Invalid encrypted file.' }
$derive = [Security.Cryptography.Rfc2898DeriveBytes]::new($password,$salt,200000,[Security.Cryptography.HashAlgorithmName]::SHA256)
try { $key = $derive.GetBytes(64) } finally { $derive.Dispose(); $password = $null }
$mac = [Security.Cryptography.HMACSHA256]::new()
try {
    $mac.Key = [byte[]]$key[32..63]
    [byte[]]$signed = [Text.Encoding]::ASCII.GetBytes('ICMS15') + $salt + $iv + $cipher
    $actual = $mac.ComputeHash($signed)
} finally { $mac.Dispose() }
$difference = 0
for ($i=0; $i -lt 32; $i++) { $difference = $difference -bor ($tag[$i] -bxor $actual[$i]) }
if ($difference -ne 0) { throw 'Wrong password or damaged file. Nothing was extracted.' }
$aes = [Security.Cryptography.Aes]::Create()
try {
    $aes.Key = [byte[]]$key[0..31]
    $aes.IV = $iv
    $aes.Mode = [Security.Cryptography.CipherMode]::CBC
    $aes.Padding = [Security.Cryptography.PaddingMode]::PKCS7
    $decrypt = $aes.CreateDecryptor()
    try { $plain = $decrypt.TransformFinalBlock($cipher,0,$cipher.Length) }
    finally { $decrypt.Dispose() }
} finally { $aes.Dispose(); [Array]::Clear($key,0,$key.Length) }
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$zip = Join-Path $OutputDirectory 'changes.zip'
[IO.File]::WriteAllBytes($zip,$plain)
Expand-Archive -LiteralPath $zip -DestinationPath $OutputDirectory
Write-Host "Decrypted archive retained at $zip"
Write-Host "Extracted verified files to $OutputDirectory"
Write-Host "Next, from the CCAS-15364 repository root: & '$OutputDirectory/Apply-Changes.ps1'"
