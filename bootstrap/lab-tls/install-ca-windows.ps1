<#
Trust the lab CA on a Windows machine (current user; no admin needed, Windows asks to confirm
each trust-store change). Also points Node-based tools (e.g. Claude Code) at it via
NODE_EXTRA_CA_CERTS. Re-running it after a CA rotation installs the new CA and removes the
retired lab CA certificates from the same store.

  .\install-ca-windows.ps1 -SshHost user@k3s-server  # fetch it over ssh with kubectl
  .\install-ca-windows.ps1 -CaFile .\lab-ca.pem      # file from export-ca.sh
  .\install-ca-windows.ps1 -Uninstall

Chrome and Edge use the Windows store; Firefox needs security.enterprise_roots.enabled = true.
#>
param(
  [string]$CaFile,
  [string]$SshHost,
  [string]$Dest = "$env:USERPROFILE\.lab\lab-ca.pem",
  [switch]$Uninstall
)
$ErrorActionPreference = 'Stop'
# Subjects the lab CA has used: 'CN=lab CA' (retired 2026-11-07), then 'CN=lab root CA <yyyy-mm>'.
$labSubject = '^CN=lab (root )?CA( \d{4}-\d{2})?$'

function Get-LabRoots { Get-ChildItem Cert:\CurrentUser\Root | Where-Object { $_.Subject -match $labSubject } }

if ($Uninstall) {
  Get-LabRoots | Remove-Item
  [Environment]::SetEnvironmentVariable('NODE_EXTRA_CA_CERTS', $null, 'User')
  Write-Host 'lab CA removed'
  return
}

New-Item -ItemType Directory -Force (Split-Path $Dest) | Out-Null
if ($SshHost) {
  $pem = ssh $SshHost "kubectl -n cert-manager get secret lab-ca -o jsonpath='{.data.tls\.crt}' | base64 -d"
  if ($LASTEXITCODE -ne 0 -or -not ($pem -match 'BEGIN CERTIFICATE')) { throw "could not read the CA from $SshHost" }
  Set-Content -Path $Dest -Value $pem -Encoding ascii
} elseif ($CaFile) {
  Copy-Item $CaFile $Dest -Force
} else { throw 'pass -SshHost or -CaFile' }

$cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2 $Dest
if ($cert.Subject -notmatch $labSubject) { throw "unexpected certificate subject: $($cert.Subject)" }
$ku = $cert.Extensions | Where-Object { $_ -is [System.Security.Cryptography.X509Certificates.X509KeyUsageExtension] }
if (-not $ku -or -not ($ku.KeyUsages -band [System.Security.Cryptography.X509Certificates.X509KeyUsageFlags]::KeyCertSign)) {
  throw 'this CA has no keyCertSign key usage; it is the retired CA - check the cluster secret'
}
Write-Host "lab CA: $($cert.Subject)  SHA1 $($cert.Thumbprint)  expires $($cert.NotAfter)"

Import-Certificate -FilePath $Dest -CertStoreLocation Cert:\CurrentUser\Root | Out-Null
$retired = @(Get-LabRoots | Where-Object Thumbprint -ne $cert.Thumbprint)
foreach ($old in $retired) {
  Write-Host "removing retired lab CA $($old.Subject) ($($old.Thumbprint))"
  $old | Remove-Item
}
[Environment]::SetEnvironmentVariable('NODE_EXTRA_CA_CERTS', $Dest, 'User')
Write-Host "trusted for this user; NODE_EXTRA_CA_CERTS=$Dest (new terminals pick it up)"
