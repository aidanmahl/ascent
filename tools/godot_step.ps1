# Shared by validate.ps1 and screenshot.ps1. Dot-source this, then call
# Invoke-GodotStep. $root must already be set by the caller.
#
# $p.ExitCode is unreliable to read back after WaitForExit()/Wait-Process in
# this environment (comes back empty even once HasExited is true), so each
# step's child writes its own exit code to a file via cmd.exe's %errorlevel%
# instead of us reading it off the Process object. Any hang is caught by
# polling for that file with a hard timeout, then killed by process name -
# per CLAUDE.md's process-safety rule, this is the ONLY place godot_console
# gets invoked; every tool goes through this.
function Invoke-GodotStep {
  param(
    [string]$GodotArgLine,
    [string]$StepName,
    [string]$OutFile,
    [string]$ErrFile,
    [int]$TimeoutSeconds
  )

  $exitFile = Join-Path $root "exitcode_$StepName.txt"
  $runnerFile = Join-Path $root "tools\_godot_step_runner_$StepName.cmd"

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
