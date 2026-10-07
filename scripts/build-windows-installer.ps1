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

function Find-InnoSetupCompiler {
    $command = Get-Command 'ISCC.exe' -ErrorAction SilentlyContinue
    if ($null -ne $command) { return $command.Source }
    $candidates = @(
        "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
        "$env:ProgramFiles\Inno Setup 6\ISCC.exe",
        "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe"
    )
    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) { return $candidate }
    }
    throw 'Inno Setup 6 is not installed. Install it with: winget install JRSoftware.InnoSetup'
}

$projectRoot = Split-Path $PSScriptRoot -Parent
Push-Location $projectRoot
try {
    $defineFile = "envs/$Environment/dart-define.env"
    if (!(Test-Path $defineFile)) {
        throw "Missing $defineFile. Restore the environment configuration first."
    }
    $iscc = Find-InnoSetupCompiler

    Invoke-ProjectCommand -CommandArgs @('flutter', 'pub', 'get')
    Invoke-ProjectCommand -CommandArgs @(
        'flutter', 'build', 'windows', '--release',
        '--dart-define-from-file', $defineFile,
        '--obfuscate', '--split-debug-info=build/obfuscate/windows'
    )

    $bundleDir = Join-Path $projectRoot 'build/windows/x64/runner/Release'
    if (!(Test-Path (Join-Path $bundleDir 'do_x.exe'))) {
        throw "Flutter did not produce $bundleDir/do_x.exe."
    }

    # Ship the MSVC runtime next to the exe so the app starts on a PC that has
    # never installed the Visual C++ Redistributable.
    foreach ($dll in @('msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll')) {
        $source = Join-Path "$env:SystemRoot\System32" $dll
        if (!(Test-Path $source)) { throw "Missing $source on the build machine." }
        Copy-Item $source $bundleDir -Force
    }

    # Four-part version, with Flutter's build number as the last component.
    $versionMatch = [regex]::Match(
        (Get-Content pubspec.yaml -Raw),
        '(?m)^version:\s*(\d+)\.(\d+)\.(\d+)(?:\+(\d+))?\s*$'
    )
    if (!$versionMatch.Success) { throw 'Cannot read the app version from pubspec.yaml.' }
    $buildNumber = if ($versionMatch.Groups[4].Success) { $versionMatch.Groups[4].Value } else { '0' }
    $appVersion = "$($versionMatch.Groups[1].Value).$($versionMatch.Groups[2].Value).$($versionMatch.Groups[3].Value).$buildNumber"

    $outputDir = Join-Path $projectRoot 'build/windows/installer'
    & $iscc '/Q' "/DAppVersion=$appVersion" "/DSourceDir=$bundleDir" "/DOutputDir=$outputDir" 'windows/installer/do-x.iss'
    if ($LASTEXITCODE -ne 0) { throw "ISCC failed with exit code $LASTEXITCODE." }

    $installer = Join-Path $outputDir 'do-x-setup.exe'
    if (!(Test-Path $installer)) { throw "Inno Setup did not produce $installer." }
    Write-Host "Created build/windows/installer/do-x-setup.exe ($appVersion)"
} finally {
    Pop-Location
}
