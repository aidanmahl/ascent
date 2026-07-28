$root = $PWD.Path
. (Join-Path $root "tools\godot_step.ps1")

# Web exports are far slower than the test suite, especially the first one
# after templates are installed - validate.cmd's 120s budget would read as
# a build failure here, so this step gets its own, much longer, timeout.
$timeoutSeconds = 600

$docsDir = Join-Path $root "docs"
$indexPath = Join-Path $docsDir "index.html"
$wasmPath = Join-Path $docsDir "index.wasm"
$pckPath = Join-Path $docsDir "index.pck"
$jsPath = Join-Path $docsDir "index.js"

New-Item -ItemType Directory -Force -Path $docsDir | Out-Null

$outFile = Join-Path $root "out_build_web.txt"
$errFile = Join-Path $root "err_build_web.txt"

$result = Invoke-GodotStep -GodotArgLine "--headless --path . --export-release `"Web`" docs/index.html" `
  -StepName "build_web" -OutFile $outFile -ErrFile $errFile -TimeoutSeconds $timeoutSeconds

if ($result.TimedOut) {
  Write-Host "=== WEB EXPORT TIMED OUT after ${timeoutSeconds}s - process killed ==="
  Get-Content $outFile, $errFile -ErrorAction SilentlyContinue
  exit 1
}

Get-Content $outFile, $errFile -ErrorAction SilentlyContinue

if ($result.ExitCode -ne "0") {
  Write-Host "=== WEB EXPORT FAILED (exit $($result.ExitCode)) ==="
  exit 1
}
if (Select-String -Path $outFile, $errFile -Pattern "SCRIPT ERROR", "Parse Error" -Quiet -ErrorAction SilentlyContinue) {
  Write-Host "=== SCRIPT ERRORS ==="
  exit 1
}

$missing = @()
foreach ($f in @($indexPath, $wasmPath, $pckPath, $jsPath)) {
  if (-not (Test-Path $f)) { $missing += $f }
}
if ($missing.Count -gt 0) {
  Write-Host "=== MISSING EXPORT ARTIFACTS ==="
  $missing | ForEach-Object { Write-Host " - $_" }
  exit 1
}

$nojekyll = Join-Path $docsDir ".nojekyll"
if (-not (Test-Path $nojekyll)) {
  New-Item -ItemType File -Path $nojekyll | Out-Null
}

Remove-Item $outFile, $errFile -ErrorAction SilentlyContinue
Write-Host "=== WEB BUILD OK ==="
exit 0
