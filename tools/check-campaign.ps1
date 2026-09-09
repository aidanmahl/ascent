param([switch]$Resume)
$root = $PWD.Path
. (Join-Path $root 'tools\godot_step.ps1')
$resumeArg = if ($Resume) { '-- --resume' } else { '' }
for ($batch = 1; $batch -le 20; $batch++) {
  $outFile = Join-Path $root 'out_campaign_replay.txt'
  $errFile = Join-Path $root 'err_campaign_replay.txt'
  $result = Invoke-GodotStep -GodotArgLine "--headless --path . --script res://tests/campaign_replay.gd $resumeArg" -StepName 'campaign_replay' -OutFile $outFile -ErrFile $errFile -TimeoutSeconds 110
  Get-Content $outFile, $errFile -ErrorAction SilentlyContinue
  if ($result.TimedOut) { exit 1 }
  if (Select-String -Path $outFile,$errFile -Pattern 'SCRIPT ERROR','Parse Error' -Quiet -ErrorAction SilentlyContinue) { exit 1 }
  if ($result.ExitCode -eq '0') { Write-Host '=== CAMPAIGN ROUTE OK ==='; exit 0 }
  if ($result.ExitCode -ne '2') { exit 1 }
  $resumeArg = '-- --resume'
}
Write-Error 'Campaign replay exceeded its bounded batch count'
exit 1
