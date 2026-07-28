$root = $PWD.Path

# $p.ExitCode is unreliable to read back after WaitForExit()/Wait-Process in this
# environment (comes back empty even once HasExited is true), so each step's
# child writes its own exit code to a file via cmd.exe's %errorlevel% instead
# of us reading it off the Process object.
function Invoke-GodotStep {
  param(
    [string]$GodotArgLine,
    [string]$StepName,
    [string]$OutFile,
    [string]$ErrFile,
    [int]$TimeoutSeconds
  )

  $exitFile = Join-Path $root "exitcode_$StepName.txt"
  $runnerFile = Join-Path $root "tools\_validate_runner_$StepName.cmd"

  Remove-Item $OutFile, $ErrFile, $exitFile, $runnerFile -ErrorAction SilentlyContinue

  @"
@echo off
godot_console $GodotArgLine 1>"$OutFile" 2>"$ErrFile"
echo %errorlevel% > "$exitFile"
"@ | Set-Content -Path $runnerFile -Encoding ascii

  $p = Start-Process -FilePath "cmd.exe" -ArgumentList "/c", "`"$runnerFile`"" `
    -WorkingDirectory $root -NoNewWindow -PassThru

  $sw = [System.Diagnostics.Stopwatch]::StartNew()
  while (-not (Test-Path $exitFile) -and $sw.Elapsed.TotalSeconds -lt $TimeoutSeconds) {
    Start-Sleep -Milliseconds 100
  }

  if (-not (Test-Path $exitFile)) {
    Get-Process -Name "godot_console" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
    Remove-Item $runnerFile -ErrorAction SilentlyContinue
    return @{ TimedOut = $true; ExitCode = $null }
  }

  $exitCode = (Get-Content $exitFile -ErrorAction SilentlyContinue | Select-Object -First 1)
  if ($null -ne $exitCode) { $exitCode = $exitCode.Trim() }
  Remove-Item $runnerFile, $exitFile -ErrorAction SilentlyContinue

  return @{ TimedOut = $false; ExitCode = $exitCode }
}

# Step 1: force a project rescan so any new class_name scripts get registered
# in the global class cache. Without this, a fresh class referenced from a
# just-written script fails to parse ("Could not find type X in the current
# scope") because the cache is stale, and since that's a load-time failure
# (not a runtime hang) the test scene's own watchdog never gets a chance to
# run - only this step catches it.
$importOut = Join-Path $root "out_import.txt"
$importErr = Join-Path $root "err_import.txt"
$importResult = Invoke-GodotStep -GodotArgLine "--headless --path . --import" -StepName "import" `
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

# Step 2: run the actual headless test suite.
$outFile = Join-Path $root "out.txt"
$errFile = Join-Path $root "err.txt"
$testTimeoutSeconds = 120
$testResult = Invoke-GodotStep -GodotArgLine "--headless --path . --quit-after 100000 res://tests/run_tests.tscn" `
  -StepName "tests" -OutFile $outFile -ErrFile $errFile -TimeoutSeconds $testTimeoutSeconds

if ($testResult.TimedOut) {
  Write-Host "=== TIMED OUT after ${testTimeoutSeconds}s - process killed ==="
  Get-Content $outFile, $errFile -ErrorAction SilentlyContinue
  exit 1
}

Get-Content $outFile, $errFile -ErrorAction SilentlyContinue

if ($testResult.ExitCode -ne "0") {
  Write-Host "=== TESTS FAILED (exit $($testResult.ExitCode)) ==="
  exit 1
}
if (Select-String -Path $outFile, $errFile -Pattern "SCRIPT ERROR", "Parse Error" -Quiet -ErrorAction SilentlyContinue) {
  Write-Host "=== SCRIPT ERRORS ==="
  exit 1
}
Write-Host "=== OK ==="
exit 0
