$root = $PWD.Path
. (Join-Path $root "tools\godot_step.ps1")

$configPath = Join-Path $root "tools\capture\capture_config.json"
if (-not (Test-Path $configPath)) {
  Write-Host "=== No tools\capture\capture_config.json found - write one first ==="
  exit 1
}

# Same reason as validate.ps1's import step: a brand-new .tscn/.gd that
# Godot has never scanned can fail to load silently (no script error, no
# watchdog message, just a clean-looking exit 0 that did nothing) rather
# than a visible error. Cheap enough to always run.
$importOut = Join-Path $root "out_screenshot_import.txt"
$importErr = Join-Path $root "err_screenshot_import.txt"
$importResult = Invoke-GodotStep -GodotArgLine "--headless --path . --import" -StepName "screenshot_import" `
  -OutFile $importOut -ErrFile $importErr -TimeoutSeconds 60
if ($importResult.TimedOut) {
  Write-Host "=== IMPORT TIMED OUT after 60s - process killed ==="
  Get-Content $importOut, $importErr -ErrorAction SilentlyContinue
  exit 1
}
if ($importResult.ExitCode -ne "0") {
  Write-Host "=== IMPORT FAILED (exit $($importResult.ExitCode)) ==="
  Get-Content $importOut, $importErr -ErrorAction SilentlyContinue
  exit 1
}
Remove-Item $importOut, $importErr -ErrorAction SilentlyContinue

# Not --headless: there's no rendering server in headless mode, so
# get_viewport().get_texture() can't produce real pixels there. This opens
# a real (if brief) window - --audio-driver Dummy at least keeps it silent.
# The scene's own watchdog Timer (30s) is the primary exit guarantee; this
# outer timeout is just the same kill-on-hang safety net every other
# godot_console invocation goes through.
$outFile = Join-Path $root "out_screenshot.txt"
$errFile = Join-Path $root "err_screenshot.txt"
$result = Invoke-GodotStep -GodotArgLine "--path . --audio-driver Dummy --position 100,100 res://tools/capture/screenshot_driver.tscn" `
  -StepName "screenshot" -OutFile $outFile -ErrFile $errFile -TimeoutSeconds 45

if ($result.TimedOut) {
  Write-Host "=== TIMED OUT after 45s - process killed ==="
  Get-Content $outFile, $errFile -ErrorAction SilentlyContinue
  exit 1
}

Get-Content $outFile, $errFile -ErrorAction SilentlyContinue

if ($result.ExitCode -ne "0") {
  Write-Host "=== CAPTURE FAILED (exit $($result.ExitCode)) ==="
  exit 1
}

Write-Host "=== OK ==="
exit 0
