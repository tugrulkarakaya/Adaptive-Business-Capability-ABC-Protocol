param([Parameter(Mandatory=$true)][string]$InputFile, [string]$Destination)
$ErrorActionPreference = 'Stop'
$secure = Read-Host 'Transfer password' -AsSecureString
$ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
try { $password = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr) }
finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr) }
[byte[]]$data = [Convert]::FromBase64String([IO.File]::ReadAllText((Resolve-Path -LiteralPath $InputFile)))
if ($data.Length -lt 80 -or (($data.Length-64) % 16) -ne 0) { throw 'Invalid transfer data.' }
[byte[]]$salt=$data[0..15]; [byte[]]$iv=$data[16..31]; [byte[]]$tag=$data[32..63]
$kdf=[Security.Cryptography.Rfc2898DeriveBytes]::new($password,$salt,200000,[Security.Cryptography.HashAlgorithmName]::SHA256)
try { [byte[]]$key=$kdf.GetBytes(64) } finally { $kdf.Dispose(); $password=$null }
try {
    [byte[]]$macKey=$key[32..63]
    $hmac=[Security.Cryptography.HMACSHA256]::new($macKey)
    [byte[]]$authenticated=[byte[]]::new($data.Length-32)
    [Array]::Copy($data,0,$authenticated,0,32)
    [Array]::Copy($data,64,$authenticated,32,$data.Length-64)
    try { [byte[]]$actual=$hmac.ComputeHash($authenticated) } finally { $hmac.Dispose() }
    $different=0
    for ($i=0;$i -lt 32;$i++) { $different=$different -bor ($actual[$i] -bxor $tag[$i]) }
    if ($different -ne 0) { throw 'Wrong password or damaged file. Nothing extracted.' }
    $aes=[Security.Cryptography.Aes]::Create()
    $aes.Key=[byte[]]$key[0..31]; $aes.IV=$iv
    $aes.Mode=[Security.Cryptography.CipherMode]::CBC; $aes.Padding=[Security.Cryptography.PaddingMode]::PKCS7
    $decryptor=$aes.CreateDecryptor()
    try { [byte[]]$zip=$decryptor.TransformFinalBlock($data,64,$data.Length-64) }
    finally { $decryptor.Dispose(); $aes.Dispose() }
    if (!$Destination) { $Destination=Join-Path (Split-Path (Resolve-Path -LiteralPath $InputFile)) ('transfer-'+(Get-Date -Format 'yyyyMMdd-HHmmss-fff')) }
    if (![IO.Path]::IsPathRooted($Destination)) { $Destination=Join-Path (Get-Location).ProviderPath $Destination }
    if (Test-Path -LiteralPath $Destination) { throw 'Choose a new destination folder. Existing files were not changed.' }
    New-Item -ItemType Directory -Path $Destination | Out-Null
    $archive=Join-Path $Destination 'payload.zip'
    [IO.File]::WriteAllBytes($archive,$zip)
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [IO.Compression.ZipFile]::ExtractToDirectory($archive,$Destination)
    Write-Host "Integrity verified and extracted: $Destination"
    Write-Host 'Review README.txt, then run Apply-Changes.ps1 against your feature branch.'
} finally {
    if ($key) { [Array]::Clear($key,0,$key.Length) }
    if ($macKey) { [Array]::Clear($macKey,0,$macKey.Length) }
    if ($zip) { [Array]::Clear($zip,0,$zip.Length) }
    $secure.Dispose()
}
