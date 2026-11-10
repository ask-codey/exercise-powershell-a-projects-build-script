# Exercise: A Project's Build Script

Exercise code for the lesson **Exercise: A Project's Build Script** in PowerShell in Depth on [ask-codey.com](https://www.ask-codey.com).

Maple Street Bikes has a small website, and a `build.ps1` that so far does one job: it copies the site into `dist`. Give it the other jobs every project needs: check that the tools are installed, test the pages, zip a release, and publish it, with the deploy token kept out of the script. A Pester check runs each of your tasks the way a build server would, and tells you what's done.

## What's here

- `src\`: the website: three pages and a style sheet. One page has a broken link for your test task to find; fix it when it does.
- `tools\check-pages.ps1`: a page checker. It checks that every page has a title and that every link to another page leads somewhere, prints what it found, and ends with exit code 0 when every page passes, 1 when one doesn't. Ready to use; don't change it.
- `build.ps1`: the build script. The `build` task is written. The `check`, `test`, `package` and `publish` tasks are for you to write.
- `Check.Tests.ps1`: the check. You don't need to change it.

## What to do

Open PowerShell 7 in this folder (the one with `build.ps1` in it), and open the script in VS Code or `edit`. Each task is a function, and the `switch` at the bottom runs the one you name. The comment above each function says what it does. Replace each `throw '... is not written yet.'` with your own code:

1. **`check`**: for each tool in `$tools` (`git` and `pwsh`), find it with `Get-Command`. Print `Found git`, `Found pwsh`. When a tool is missing, stop with an error that names it.
2. **`test`**: run the page checker on `src` as its own program: `pwsh -NoProfile -File $checker -Path $src`. When it ends with exit code 0, print `All pages passed`. When it doesn't, stop with an error. Run the task, and fix the broken link it finds in `src`.
3. **`package`**: run the test first, then the build, then zip everything inside `dist` into the file in `$zip` (`release\bike-shop-site-1.2.0.zip`) with `Compress-Archive`. A site that fails its test is never zipped.
4. **`publish`**: the web host needs a deploy token, kept in `$env:BIKESHOP_DEPLOY_TOKEN`. When it isn't set, stop with an error that names that variable, before anything else happens. When it is, package, then copy the zip into the `server` folder (the path in `$server`), which stands in for the web host. Never print the token.

Try each task as you go:

```powershell
.\build.ps1 -Task check
```

To try `publish`, set a pretend token for this window first. It's only practice, so any text will do:

```powershell
$env:BIKESHOP_DEPLOY_TOKEN = 'practice-token'
.\build.ps1 -Task publish
```

## Check your work

The check needs Pester 5 or newer. Install it once, if you haven't already:

```powershell
Install-PSResource Pester
```

Then, from this folder:

```powershell
Invoke-Pester
```

At first most tests fail: that is expected. Each task you finish turns its test green. A failing test's message says what to look at. The check copies your `build.ps1` into a throwaway folder beside a small site of its own, runs each task from another folder with `pwsh -File`, once with good pages and once with a broken link, and sets `PATH` and the deploy token for those runs only. It never changes your files. It doesn't need Git: it brings a stand-in `git` of its own.

If PowerShell says the check *cannot be loaded* because it *is not digitally signed*, or because *running scripts is disabled*, the folder came from a download that Windows marked as from the internet. Unblock its files once with `Get-ChildItem -Recurse | Unblock-File`, from this folder, and run `Invoke-Pester` again.

## The rules

- Keep the names: `build.ps1`, its five tasks, and the variables at its top. The check runs `.\build.ps1 -Task <name>` and looks for the zip and the server folder where `$zip` and `$server` say.
- Find every file through `$PSScriptRoot` (the variables at the top already do), so the script works from any folder.
- Never write a token into the script, and never print it.

## Tips

- `Get-Command git -ErrorAction SilentlyContinue` gives back nothing when git isn't installed, so `if (-not (Get-Command ...))` asks "is it missing?"
- `throw "Install $tool first: this project needs it."` stops the script with your message. With `$ErrorActionPreference = 'Stop'` at the top, any other error stops it too.
- Right after a program ends, `$LASTEXITCODE` holds its exit code: 0 when it worked.
- One task can call another: `Invoke-TestTask` inside `Invoke-PackageTask` runs the test first.
- `Compress-Archive -Path "$dist\*"` zips what's inside `dist`, not the `dist` folder itself. Add `-Force` so a second run replaces the zip, and make the `release` folder first with `New-Item -ItemType Directory -Force`.
- `if (-not $env:BIKESHOP_DEPLOY_TOKEN)` is true when the variable isn't set, or is empty.

## Hand it in

When it works, push your solution to a public repo of your own on GitHub, then paste that repo's address into **Submit your exercise** on the lesson page at [ask-codey.com](https://www.ask-codey.com). That's what completes the lesson. The lesson page shows the Git commands, step by step. The `.gitignore` keeps `dist`, `release` and `server` out of your repo: they're made by the script, so they don't need to be saved.
