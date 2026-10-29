param([switch]$Install)

$ErrorActionPreference = 'Stop'
$path = Join-Path $env:TEMP 'teacher-workbench-pilot-root-ca-20261024.crt'
$expectedSha256 = '1BD4D9B8393BFCBCB3E9FF03C3236E47810F91D852E907ED91CE38C0F6944789'
if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw 'Public pilot CA file missing.' }

function Get-CertificateSha256([System.Security.Cryptography.X509Certificates.X509Certificate2]$item) {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        return [System.BitConverter]::ToString($sha.ComputeHash($item.RawData)).Replace('-', '')
    } finally {
        $sha.Dispose()
    }
}

$certificate = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($path)
$actualSha256 = Get-CertificateSha256 $certificate
if ($actualSha256 -ne $expectedSha256) { throw 'Pilot CA fingerprint differs; stop.' }
if ($certificate.Subject -ne $certificate.Issuer) { throw 'Pilot CA is not self issued; stop.' }
$constraints = $certificate.Extensions | Where-Object {
    $_ -is [System.Security.Cryptography.X509Certificates.X509BasicConstraintsExtension]
}
if (-not $constraints -or -not $constraints.CertificateAuthority) {
    throw 'Pilot CA certificate constraints are unexpected; stop.'
}
Write-Output 'PILOT_CA_PUBLIC_CERT_FINGERPRINT_AND_TYPE_OK'

$store = 'Cert:\CurrentUser\Root'
$existing = Get-ChildItem $store | Where-Object {
    (Get-CertificateSha256 $_) -eq $expectedSha256
}
if ($existing) {
    Write-Output 'PILOT_CA_ALREADY_TRUSTED_FOR_CURRENT_USER'
    return
}
if (-not $Install) {
    Write-Output 'PILOT_CA_NOT_TRUSTED_FOR_CURRENT_USER_NO_CHANGE'
    return
}

# Installing a root CA changes trust for this Windows user; run only after
# explicit approval for this exact certificate fingerprint and scope.
Import-Certificate -FilePath $path -CertStoreLocation $store -ErrorAction Stop | Out-Null
$installed = Get-ChildItem $store | Where-Object {
    (Get-CertificateSha256 $_) -eq $expectedSha256
}
if (-not $installed) { throw 'Current-user pilot CA import could not be confirmed.' }
Write-Output 'PILOT_CA_TRUSTED_FOR_CURRENT_USER'
