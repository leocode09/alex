$ErrorActionPreference = 'Stop'
$idxPath = 'C:\i\alex\.cursor\hooks\state\continual-learning-index.json'
$idx = Get-Content $idxPath -Raw | ConvertFrom-Json
$root = 'C:\Users\leoco\.cursor\projects\c-i-alex\agent-transcripts'
$map = @{}
foreach ($prop in $idx.transcripts.PSObject.Properties) {
  $map[$prop.Name] = $prop.Value
}
Get-ChildItem -Path $root -Recurse -Filter '*.jsonl' | ForEach-Object {
  $p = $_.FullName
  $ms = [int64]([DateTimeOffset]$_.LastWriteTimeUtc).ToUnixTimeMilliseconds()
  $old = $map[$p]
  if (-not $old) {
    Write-Output "NEW`t$ms`t$p"
  } elseif ($ms -gt $old.mtimeMs) {
    Write-Output "CHG`t$ms`t$($old.mtimeMs)`t$p"
  }
}
foreach ($k in $map.Keys) {
  if (-not (Test-Path -LiteralPath $k)) {
    Write-Output "DELIDX`t$k"
  }
}
