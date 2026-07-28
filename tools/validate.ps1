$timeoutSeconds = 120
$root = $PWD.Path
$outFile = Join-Path $root "out.txt"
$errFile = Join-Path $root "err.txt"
$exitFile = Join-Path $root "exitcode.txt"
$runnerFile = Join-Path $root "tools\_validate_runner.cmd"

Remove-Item $outFile, $errFile, $exitFile, $runnerFile -ErrorAction SilentlyContinue

# $p.ExitCode is unreliable to read back after WaitForExit()/Wait-Process in this
# environment (comes back empty even once HasExited is true), so the child writes
# its own exit code to a file via cmd.exe's %errorlevel% instead of us reading it
# off the Process object.
@"
@echo off
godot_console --headless --path . --quit-after 100000 res://tests/run_tests.tscn 1>"$outFile" 2>"$errFile"
echo %errorlevel% > "$exitFile"
"@ | Set-Content -Path $runnerFile -Encoding ascii

$p = Start-Process -FilePath "cmd.exe" -ArgumentList "/c", "`"$runnerFile`"" `
  -WorkingDirectory $root -NoNewWindow -PassThru

$sw = [System.Diagnostics.Stopwatch]::StartNew()
while (-not (Test-Path $exitFile) -and $sw.Elapsed.TotalSeconds -lt $timeoutSeconds) {
  Start-Sleep -Milliseconds 100
}

if (-not (Test-Path $exitFile)) {
  Get-Process -Name "godot_console" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
  Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
  Write-Host "=== TIMED OUT after ${timeoutSeconds}s - process killed ==="
  Get-Content $outFile, $errFile -ErrorAction SilentlyContinue
  Remove-Item $runnerFile -ErrorAction SilentlyContinue
  exit 1
}

$exitCode = (Get-Content $exitFile -ErrorAction SilentlyContinue | Select-Object -First 1)
if ($null -ne $exitCode) { $exitCode = $exitCode.Trim() }
Remove-Item $runnerFile -ErrorAction SilentlyContinue

Get-Content $outFile, $errFile -ErrorAction SilentlyContinue

if ($exitCode -ne "0") {
  Write-Host "=== TESTS FAILED (exit $exitCode) ==="
  exit 1
}
if (Select-String -Path $outFile, $errFile -Pattern "SCRIPT ERROR", "Parse Error" -Quiet -ErrorAction SilentlyContinue) {
  Write-Host "=== SCRIPT ERRORS ==="
  exit 1
}
Write-Host "=== OK ==="
exit 0
