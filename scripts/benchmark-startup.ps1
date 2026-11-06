param(
    [string]$Executable = "$PSScriptRoot/../build/windows/x64/runner/Release/better_notes.exe",
    [ValidateRange(0, 20)][int]$Notes = 10,
    [ValidateRange(1, 10)][int]$Runs = 5,
    [string]$OutputDirectory = "$PSScriptRoot/../build/startup-benchmark",
    [ValidateSet(1, 2)][int]$Concurrency = 1
)

$ErrorActionPreference = 'Stop'
$executablePath = (Resolve-Path -LiteralPath $Executable).Path
$null = New-Item -ItemType Directory -Force -Path $OutputDirectory
$outputPath = (Resolve-Path -LiteralPath $OutputDirectory).Path
$results = @()
for ($run = 1; $run -le $Runs; $run++) {
    $resultFile = Join-Path $outputPath ("notes-{0}-run-{1}-{2}.json" -f $Notes, $run, [guid]::NewGuid())
    $clock = [Diagnostics.Stopwatch]::StartNew()
    # This is the app's interactive presentation check, not a background helper.
    # A Hidden startup flag suppresses the runner's first ShowWindow call and
    # would make a first-frame timing a misleading proxy for a usable library.
    $process = Start-Process -FilePath $executablePath -WorkingDirectory (Split-Path $executablePath) -WindowStyle Normal -PassThru -ArgumentList @(
        '--ui-review', "--startup-benchmark=$Notes", "--startup-concurrency=$Concurrency",
        ('--benchmark-output="{0}"' -f $resultFile)
    )
    while (!(Test-Path -LiteralPath $resultFile) -and !$process.HasExited -and $clock.Elapsed.TotalSeconds -lt 120) {
        Start-Sleep -Milliseconds 100
        $process.Refresh()
    }
    if (!(Test-Path -LiteralPath $resultFile)) {
        $reason = if ($process.HasExited) { "exited with code $($process.ExitCode)" } else { 'exceeded the startup deadline' }
        throw "Benchmark $reason. Diagnostic process ID: $($process.Id). Other BetterNotes processes were not touched."
    }
    $observedMs = $clock.ElapsedMilliseconds
    # The diagnostic app waits two seconds after writing its result, then quits
    # through the normal save/close path. Sample memory before it exits.
    $process.Refresh()
    $peakMB = [math]::Round($process.PeakWorkingSet64 / 1MB, 1)
    $settledMB = [math]::Round($process.WorkingSet64 / 1MB, 1)
    $cpuMs = [math]::Round($process.TotalProcessorTime.TotalMilliseconds)
    if (!$process.WaitForExit(15000)) {
        throw "Diagnostic process $($process.Id) did not quit normally; inspect it before another run."
    }
    $timing = Get-Content -LiteralPath $resultFile -Raw | ConvertFrom-Json
    $result = [pscustomobject]@{
        notes = $Notes; concurrency = $Concurrency; run = $run
        observedLaunchToResultMs = $observedMs
        firstFrameMs = $timing.marksMs.mainFirstFrame - $timing.marksMs.fixtureReady
        restoreMs = $timing.marksMs.restoreComplete - $timing.marksMs.fixtureReady
        nativeCreateMs = $timing.workMs.nativeCreate
        peakWorkingSetMB = $peakMB; sampledWorkingSetMB = $settledMB; cpuMs = $cpuMs
        rawResult = $resultFile
    }
    $results += $result
    $result | ConvertTo-Json -Compress | Write-Output
}
$results | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $outputPath "summary-$Notes-$Concurrency.json") -Encoding UTF8
