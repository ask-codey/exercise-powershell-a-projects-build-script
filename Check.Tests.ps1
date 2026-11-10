# Checks your build.ps1, one test per task in README.md, and the site's own pages.
# Each test copies build.ps1 and tools\check-pages.ps1 into a throwaway folder that Pester makes and removes
# (TestDrive), beside a small site of the check's own, and runs a task there with pwsh -File, from another folder,
# the way a build server would. It sets PATH and $env:BIKESHOP_DEPLOY_TOKEN for that run only, so nothing here
# changes your files or your settings.
# Run it from this folder with: Invoke-Pester
# You don't need to change this file.

Describe 'Exercise: A Project''s Build Script' {

    BeforeAll {
        $script:buildScript = Join-Path $PSScriptRoot 'build.ps1'
        $script:pwsh = [System.Environment]::ProcessPath
        $script:pwshFolder = Split-Path -Parent $pwsh
        $script:separator = [System.IO.Path]::PathSeparator

        # A folder with a stand-in git in it, so the check task can find git without Git being installed.
        $script:fakeBin = Join-Path $TestDrive 'fake-bin'
        New-Item -ItemType Directory -Path $fakeBin | Out-Null
        if ($IsWindows) {
            Set-Content -Path (Join-Path $fakeBin 'git.cmd') -Value '@echo git version 2.51.1'
        }
        else {
            $fakeGit = Join-Path $fakeBin 'git'
            Set-Content -Path $fakeGit -Value '#!/bin/sh', 'echo git version 2.51.1'
            chmod +x $fakeGit
        }
        $script:systemFolders = if ($IsWindows) { @(Join-Path $env:SystemRoot 'System32') } else { @('/usr/bin', '/bin') }

        # Copies build.ps1 and the page checker into a new throwaway project with the check's own pages.
        # -BrokenLink makes index.html link to a page that isn't there.
        function New-TestProject([switch] $BrokenLink) {
            $project = Join-Path $TestDrive ('project-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
            New-Item -ItemType Directory -Path (Join-Path $project 'src'), (Join-Path $project 'tools') | Out-Null
            Copy-Item -LiteralPath $buildScript -Destination $project
            Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'tools\check-pages.ps1') -Destination (Join-Path $project 'tools')
            $target = if ($BrokenLink) { 'contact.html' } else { 'rentals.html' }
            Set-Content -Path (Join-Path $project 'src\index.html') -Value '<html><head><title>Test Shop</title></head>', "<body><a href=""$target"">Rentals</a></body></html>"
            Set-Content -Path (Join-Path $project 'src\rentals.html') -Value '<html><head><title>Test Rentals</title></head>', '<body><a href="index.html">Home</a></body></html>'
            Set-Content -Path (Join-Path $project 'src\style.css') -Value 'body { margin: 1rem; }'
            $project
        }

        # Runs one task of a project's build.ps1 with pwsh -File, from another folder. -NoGit leaves the stand-in git
        # off PATH, and -Token sets $env:BIKESHOP_DEPLOY_TOKEN for this run only. Gives back the exit code and every
        # line the script printed, errors included.
        function Invoke-Task([string] $Project, [string] $Task, [switch] $NoGit, [string] $Token) {
            $elsewhere = Join-Path $TestDrive 'elsewhere'
            New-Item -ItemType Directory -Force -Path $elsewhere | Out-Null
            $folders = @($pwshFolder) + $systemFolders
            if (-not $NoGit) { $folders = @($fakeBin) + $folders }
            $oldPath = $env:PATH
            $oldToken = $env:BIKESHOP_DEPLOY_TOKEN
            $env:PATH = $folders -join $separator
            $env:BIKESHOP_DEPLOY_TOKEN = $Token
            Push-Location -LiteralPath $elsewhere
            try {
                $all = @(& $pwsh -NoProfile -NonInteractive -ExecutionPolicy Bypass -File (Join-Path $Project 'build.ps1') -Task $Task 2>&1)
                $code = $LASTEXITCODE
            }
            finally {
                Pop-Location
                $env:PATH = $oldPath
                $env:BIKESHOP_DEPLOY_TOKEN = $oldToken
            }
            [pscustomobject]@{
                ExitCode = $code
                Text     = (@($all | ForEach-Object { "$_" }) -join "`n")
            }
        }

        function Assert-BuildScript {
            Test-Path -LiteralPath $buildScript -PathType Leaf | Should -BeTrue -Because 'build.ps1 lives in this folder. Did it get moved or renamed?'
        }
    }

    It 'build still copies the site into dist' {
        Assert-BuildScript
        $project = New-TestProject
        $run = Invoke-Task -Project $project -Task build
        $run.ExitCode | Should -Be 0 -Because "the build task should work as the starter had it. It printed: $($run.Text)"
        Join-Path $project 'dist\index.html' | Should -Exist -Because 'the build copies src into dist, from any folder, with $PSScriptRoot'
    }

    It '1) check finds the tools, and stops with the name of a missing one' {
        Assert-BuildScript
        $project = New-TestProject
        $found = Invoke-Task -Project $project -Task check
        $found.ExitCode | Should -Be 0 -Because "with git and pwsh both installed, the check task should end without an error. It printed: $($found.Text)"
        $found.Text | Should -Match 'Found git' -Because 'print a line such as Found git for each tool that Get-Command finds'
        $found.Text | Should -Match 'Found pwsh' -Because 'print a line such as Found pwsh for each tool that Get-Command finds'
        $missing = Invoke-Task -Project $project -Task check -NoGit
        $missing.ExitCode | Should -Not -Be 0 -Because 'on a computer without git, the check task should stop with an error. Use Get-Command with -ErrorAction SilentlyContinue, and throw when it finds nothing'
        $missing.Text | Should -Match 'git' -Because "the error should name the missing tool, so the reader knows what to install. It printed: $($missing.Text)"
        $missing.Text | Should -Not -Match 'Found git' -Because 'git is missing in this run, so the task should not say it found it'
    }

    It '2) test passes good pages, and stops on a broken link' {
        Assert-BuildScript
        $good = Invoke-Task -Project (New-TestProject) -Task test
        $good.ExitCode | Should -Be 0 -Because "on pages with no problems, the test task should end without an error. It printed: $($good.Text)"
        $good.Text | Should -Match 'All pages passed' -Because 'print All pages passed when the checker ends with exit code 0'
        $broken = Invoke-Task -Project (New-TestProject -BrokenLink) -Task test
        $broken.ExitCode | Should -Not -Be 0 -Because 'the checker ended with exit code 1, and the test task carried on as if nothing happened. Check $LASTEXITCODE after it, and throw when it isn''t 0 (or set $PSNativeCommandUseErrorActionPreference = $true)'
        $broken.Text | Should -Not -Match 'All pages passed' -Because 'with a broken link, the task must not say that all pages passed'
    }

    It '3) package zips a tested build, and makes no zip when a test fails' {
        Assert-BuildScript
        $project = New-TestProject
        $run = Invoke-Task -Project $project -Task package
        $run.ExitCode | Should -Be 0 -Because "the package task should end without an error. It printed: $($run.Text)"
        $zip = Join-Path $project 'release\bike-shop-site-1.2.0.zip'
        $zip | Should -Exist -Because 'the release goes into release\bike-shop-site-1.2.0.zip, the path in $zip. Compress-Archive makes it'
        $inside = Join-Path $TestDrive ('unzipped-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
        Expand-Archive -Path $zip -DestinationPath $inside
        Join-Path $inside 'index.html' | Should -Exist -Because 'the zip should hold the files from dist at its top level: zip "$dist\*", not the dist folder itself'
        Join-Path $inside 'rentals.html' | Should -Exist -Because 'the zip should hold every page from dist'
        $broken = New-TestProject -BrokenLink
        $failed = Invoke-Task -Project $broken -Task package
        $failed.ExitCode | Should -Not -Be 0 -Because 'with a broken link, the package task should stop at the test'
        Join-Path $broken 'release\bike-shop-site-1.2.0.zip' | Should -Not -Exist -Because 'a site that failed its test should never be zipped: run the test first'
    }

    It '4) publish refuses without the deploy token, and names the variable' {
        Assert-BuildScript
        $project = New-TestProject
        $run = Invoke-Task -Project $project -Task publish
        $run.ExitCode | Should -Not -Be 0 -Because 'with no deploy token set, publish should stop with an error'
        $run.Text | Should -Match 'BIKESHOP_DEPLOY_TOKEN' -Because "the error should say which variable to set: `$env:BIKESHOP_DEPLOY_TOKEN. It printed: $($run.Text)"
        @(Get-ChildItem -Path (Join-Path $project 'server') -Recurse -File -ErrorAction SilentlyContinue).Count | Should -Be 0 -Because 'without the token, nothing should reach the server folder: check for the token first'
    }

    It '5) publish copies the release to server, and never prints the token' {
        Assert-BuildScript
        $project = New-TestProject
        $token = 'check-' + [guid]::NewGuid().ToString('N')
        $run = Invoke-Task -Project $project -Task publish -Token $token
        $run.ExitCode | Should -Be 0 -Because "with the token set, publish should end without an error. It printed: $($run.Text)"
        Join-Path $project 'server\bike-shop-site-1.2.0.zip' | Should -Exist -Because 'publish packages the site, then copies the zip into the server folder, the path in $server'
        $run.Text | Should -Not -Match $token -Because 'the output showed the deploy token. Anyone who sees the screen or the build log could copy it: print that it was found, never what it is'
    }

    It '6) the site''s own pages pass the page check' {
        $checker = Join-Path $PSScriptRoot 'tools\check-pages.ps1'
        $output = @(& $pwsh -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $checker -Path (Join-Path $PSScriptRoot 'src'))
        $LASTEXITCODE | Should -Be 0 -Because "the page checker found a problem in src: $($output -join ' '). Fix the page it names"
    }
}
