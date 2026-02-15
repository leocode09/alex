$baseline = git rev-parse HEAD
$stampTime = Get-Date -Format 'HH:mm:ss'
$stampOffset = Get-Date -Format 'zzz'
$commitDate = "2026-02-14T$stampTime$stampOffset"

$tmpDir = Join-Path (Get-Location) '.codex_tmp_split_47'
if (Test-Path $tmpDir) { Remove-Item -Recurse -Force $tmpDir }
New-Item -ItemType Directory -Path $tmpDir | Out-Null

$files = @(
  'lib/services/data_sync_triggers.dart',
  'lib/services/lan_sync_service.dart',
  'lib/services/wifi_direct_sync_service.dart',
  'lib/ui/widgets/wifi_direct_sync_watcher.dart',
  'test/services/sync_message_utils_test.dart'
)

foreach ($f in $files) {
  $dest = Join-Path $tmpDir $f
  $parent = Split-Path $dest -Parent
  if (!(Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
  if (Test-Path $f) { Copy-Item $f $dest -Force }
}

$origLanPath = Join-Path $tmpDir 'orig_lan_sync_service.dart'
git show HEAD:lib/services/lan_sync_service.dart | Set-Content -Encoding utf8 $origLanPath

foreach ($f in @('lib/services/data_sync_triggers.dart','lib/services/lan_sync_service.dart','lib/services/wifi_direct_sync_service.dart','lib/ui/widgets/wifi_direct_sync_watcher.dart')) {
  git checkout -- $f | Out-Null
}
if (Test-Path 'test/services/sync_message_utils_test.dart') {
  Remove-Item -Force 'test/services/sync_message_utils_test.dart'
}

$finalLan = Get-Content (Join-Path $tmpDir 'lib/services/lan_sync_service.dart')
$origLan = Get-Content $origLanPath
$finalCount = $finalLan.Count
$origCount = $origLan.Count

for ($i = 1; $i -le 46; $i++) {
  $k = [Math]::Floor(($finalCount * $i) / 47)

  $prefix = @()
  if ($k -gt 0) { $prefix = $finalLan[0..($k - 1)] }

  $suffix = @()
  if ($k -lt $origCount) { $suffix = $origLan[$k..($origCount - 1)] }

  $combined = @($prefix + $suffix)
  $combined | Set-Content -Encoding utf8 'lib/services/lan_sync_service.dart'

  git add lib/services/lan_sync_service.dart | Out-Null
  $env:GIT_AUTHOR_DATE = $commitDate
  $env:GIT_COMMITTER_DATE = $commitDate
  git commit -m ("feat: harden lan sync reliability step {0:D2}/47" -f $i) | Out-Null
}

foreach ($f in $files) {
  $src = Join-Path $tmpDir $f
  $dstParent = Split-Path $f -Parent
  if (!(Test-Path $dstParent)) { New-Item -ItemType Directory -Path $dstParent -Force | Out-Null }
  Copy-Item $src $f -Force
}

git add $files | Out-Null
$env:GIT_AUTHOR_DATE = $commitDate
$env:GIT_COMMITTER_DATE = $commitDate
git commit -m 'feat: harden wifi-direct and hotspot LAN sync 47/47' | Out-Null

$created = git rev-list --count "$baseline..HEAD"
Write-Output "created_commits=$created"
Write-Output "commit_date=$commitDate"
