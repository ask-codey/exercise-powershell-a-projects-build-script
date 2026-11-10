# check-pages.ps1: checks the website's pages. Ready to use; you don't need to change it.
# Every .html page needs a <title>, and every link to another page of the site must lead to a page that is there.
# It prints what it found, and ends with exit code 0 when every page passes, or 1 when a page has a problem.
# Run it like this: pwsh -NoProfile -File .\tools\check-pages.ps1 -Path .\src
param(
    [Parameter(Mandatory)]
    [string] $Path
)

$problems = 0
$pages = @(Get-ChildItem -Path $Path -Filter '*.html' -File)
foreach ($page in $pages) {
    $html = Get-Content -Path $page.FullName -Raw
    if ($html -notmatch '<title>[^<]+</title>') {
        Write-Output "$($page.Name): the page has no <title>"
        $problems++
    }
    foreach ($link in [regex]::Matches($html, 'href="([^":#/]+\.html)"')) {
        $target = $link.Groups[1].Value
        if (-not (Test-Path -LiteralPath (Join-Path $Path $target))) {
            Write-Output "$($page.Name): the link to $target goes nowhere"
            $problems++
        }
    }
}

if ($problems -gt 0) {
    Write-Output "Found $problems problem(s) in $($pages.Count) pages"
    exit 1
}
Write-Output "Checked $($pages.Count) pages: no problems"
exit 0
