<#
Trust the lab CA on a Windows machine (current user; no admin needed, Windows shows one
confirmation dialog). Also points Node-based tools (e.g. Claude Code) at it via NODE_EXTRA_CA_CERTS.

  .\install-ca-windows.ps1 -CaFile .\lab-ca.pem      # file from export-ca.sh
  .\install-ca-windows.ps1 -SshHost user@k3s-server  # fetch it over ssh with kubectl
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
$subject = 'CN=lab CA'

if ($Uninstall) {
  Get-ChildItem Cert:\CurrentUser\Root | Where-Object Subject -eq $subject | Remove-Item
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
} else { throw 'pass -CaFile or -SshHost' }

$cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2 $Dest
if ($cert.Subject -ne $subject) { throw "unexpected certificate subject: $($cert.Subject)" }
Write-Host "lab CA fingerprint (SHA1): $($cert.Thumbprint)  expires $($cert.NotAfter)"
Import-Certificate -FilePath $Dest -CertStoreLocation Cert:\CurrentUser\Root | Out-Null
[Environment]::SetEnvironmentVariable('NODE_EXTRA_CA_CERTS', $Dest, 'User')
Write-Host "trusted for this user; NODE_EXTRA_CA_CERTS=$Dest (new terminals pick it up)"
