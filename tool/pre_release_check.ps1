param(
    [string]$ArtifactPath = ''
)

# Run after a release build, before distributing it.
$ErrorActionPreference = 'Stop'

dart analyze lib tool
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

if ([string]::IsNullOrWhiteSpace($ArtifactPath)) {
    dart run tool/check_no_bundled_secrets.dart
} else {
    dart run tool/check_no_bundled_secrets.dart $ArtifactPath
}

$code = $LASTEXITCODE
if ($code -eq 2) {
    Write-Host 'No packaged release artifact was found to scan. Build one first.'
    exit 2
}
if ($code -ne 0) {
    Write-Host 'Bundled secret check failed. Do not distribute this artifact.'
    exit $code
}

Write-Host 'Release checks passed.'
