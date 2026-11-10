# build.ps1: the jobs for the Maple Street Bikes website.
# Run one task at a time: .\build.ps1 -Task check (or build, test, package, publish).
# The build task is written. Write the other four where each one says "Not written yet", as README.md describes.
param(
    [ValidateSet('check', 'build', 'test', 'package', 'publish')]
    [string] $Task = 'build'
)

$ErrorActionPreference = 'Stop'
$version = '1.2.0'
$tools = 'git', 'pwsh'
$src = Join-Path $PSScriptRoot 'src'
$dist = Join-Path $PSScriptRoot 'dist'
$checker = Join-Path $PSScriptRoot 'tools\check-pages.ps1'
$zip = Join-Path $PSScriptRoot "release\bike-shop-site-$version.zip"
$server = Join-Path $PSScriptRoot 'server'

# check: make sure every tool in $tools is installed. Print "Found <tool>" for each one, and stop with an error
# that names the tool when one is missing.
function Invoke-CheckTask {
    throw 'The check task is not written yet.'
}

# build: copy the site from src into a fresh dist folder. Ready to use.
function Invoke-BuildTask {
    if (Test-Path $dist) { Remove-Item $dist -Recurse }
    Copy-Item -Path $src -Destination $dist -Recurse
    Write-Output "Built $((Get-ChildItem $dist -File).Count) files into dist"
}

# test: run the page checker on src as its own program, with pwsh. Print "All pages passed" when it ends with
# exit code 0, and stop with an error when it doesn't.
function Invoke-TestTask {
    throw 'The test task is not written yet.'
}

# package: test, then build, then zip everything in dist into the file in $zip. Stop before the zip when a test fails.
function Invoke-PackageTask {
    throw 'The package task is not written yet.'
}

# publish: package, then copy the zip into the server folder, which stands in for the web host. It needs the deploy
# token in $env:BIKESHOP_DEPLOY_TOKEN: stop with an error that names that variable when it isn't set, and never
# print the token.
function Invoke-PublishTask {
    throw 'The publish task is not written yet.'
}

switch ($Task) {
    'check' { Invoke-CheckTask }
    'build' { Invoke-BuildTask }
    'test' { Invoke-TestTask }
    'package' { Invoke-PackageTask }
    'publish' { Invoke-PublishTask }
}
