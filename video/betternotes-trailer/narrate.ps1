$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Speech
$narrator = New-Object System.Speech.Synthesis.SpeechSynthesizer
$narrator.SelectVoice('Microsoft Zira Desktop')
$narrator.Rate = 2
$narrator.Volume = 100
$beats = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'src/narration.json') -Raw | ConvertFrom-Json
foreach ($beat in $beats) {
  $outputPath = Join-Path $PSScriptRoot ('public/audio/voice-' + $beat.id + '.wav')
  $narrator.SetOutputToWaveFile($outputPath)
  $narrator.Speak($beat.text)
  $narrator.SetOutputToNull()
}
$narrator.Dispose()
Write-Output 'Created nine English narration clips using the installed Microsoft Zira voice.'
