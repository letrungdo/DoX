param(
    [ValidateSet('dev', 'staging', 'prod')]
    [string]$Environment = 'dev',
    [switch]$UseSystemFlutter
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Invoke-ProjectCommand {
    param([string[]]$CommandArgs)
    if ($UseSystemFlutter) {
        $executable = $CommandArgs[0]
        $remainingArgs = $CommandArgs[1..($CommandArgs.Count - 1)]
        & $executable @remainingArgs
    } else {
        & fvm @CommandArgs
    }
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed with exit code ${LASTEXITCODE}: $($CommandArgs[0..1] -join ' ')"
    }
}

$projectRoot = Split-Path $PSScriptRoot -Parent
Push-Location $projectRoot
try {
    $defineFile = "envs/$Environment/dart-define.env"
    if (!(Test-Path $defineFile)) {
        throw "Missing $defineFile. Restore the environment configuration first."
    }

    Invoke-ProjectCommand -CommandArgs @('flutter', 'pub', 'get')
    Invoke-ProjectCommand -CommandArgs @(
        'flutter', 'build', 'windows', '--release',
        '--dart-define-from-file', $defineFile,
        '--obfuscate', '--split-debug-info=build/obfuscate/windows'
    )

    # Keep the fourth MSIX version component in sync with Flutter's build number.
    $versionMatch = [regex]::Match(
        (Get-Content pubspec.yaml -Raw),
        '(?m)^version:\s*(\d+)\.(\d+)\.(\d+)(?:\+(\d+))?\s*$'
    )
    if (!$versionMatch.Success) { throw 'Cannot read the app version from pubspec.yaml.' }
    $buildNumber = if ($versionMatch.Groups[4].Success) { $versionMatch.Groups[4].Value } else { '0' }
    $msixVersion = "$($versionMatch.Groups[1].Value).$($versionMatch.Groups[2].Value).$($versionMatch.Groups[3].Value).$buildNumber"

    Invoke-ProjectCommand -CommandArgs @(
        'dart', 'run', 'msix:create', '--build-windows', 'false', '--version', $msixVersion
    )
    if (!(Test-Path 'build/windows/msix/do-x.msix')) {
        throw 'MSIX packaging did not produce build/windows/msix/do-x.msix.'
    }

    # Export only the public certificate used by msix's default testing signer.
    # Do not install it into the build machine's trust store.
    $configPath = (Resolve-Path '.dart_tool/package_config.json').Path
    $config = Get-Content $configPath -Raw | ConvertFrom-Json
    $msixPackage = $config.packages | Where-Object { $_.name -eq 'msix' } | Select-Object -First 1
    if ($null -eq $msixPackage) { throw 'The msix package is missing from package_config.json.' }
    $packageRoot = [Uri]::new([Uri]::new($configPath), $msixPackage.rootUri).LocalPath
    $certificatePath = Join-Path $packageRoot 'lib/assets/test_certificate.pfx'
    $certificate = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new(
        $certificatePath, '1234',
        [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::EphemeralKeySet
    )
    try {
        $publicCertificate = $certificate.Export(
            [System.Security.Cryptography.X509Certificates.X509ContentType]::Cert
        )
        [IO.File]::WriteAllBytes((Join-Path $projectRoot 'build/windows/msix/do-x.cer'), $publicCertificate)
    } finally {
        $certificate.Dispose()
    }
    Write-Host "Created build/windows/msix/do-x.msix ($msixVersion) and do-x.cer"
} finally {
    Pop-Location
}
