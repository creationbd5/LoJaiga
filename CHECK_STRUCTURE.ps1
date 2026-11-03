$required = @(
  '.github/workflows/build-ios.yml',
  'Config/Info.plist',
  'project.yml',
  'LoJaiga/LoJaigaApp.swift',
  'LoJaiga/Models/TripModels.swift',
  'LoJaiga/Services/TripStore.swift',
  'LoJaiga/Services/VoiceCommandEngine.swift',
  'LoJaiga/Services/CommandRouter.swift',
  'LoJaiga/Views/RootView.swift',
  'LoJaiga/Assets.xcassets/BrandMascot.imageset/Contents.json'
)
$missing = @()
foreach ($file in $required) {
  if (!(Test-Path (Join-Path $PSScriptRoot $file))) {
    Write-Host "MISSING: $file" -ForegroundColor Red
    $missing += $file
  } else {
    Write-Host "OK: $file" -ForegroundColor Green
  }
}
if (Test-Path (Join-Path $PSScriptRoot 'LoJaiga/LoJaiga')) {
  Write-Warning 'Unexpected nested LoJaiga/LoJaiga directory detected.'
}
if ($missing.Count -gt 0) { exit 1 }
Write-Host 'Source tree check passed. Not a Swift compilation test.' -ForegroundColor Cyan
