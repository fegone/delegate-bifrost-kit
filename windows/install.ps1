#Requires -Version 7
param([switch]$UseDocker, [int]$Port = 4010)
$ErrorActionPreference = 'Stop'
$Sha = '2c43bdb17402ec277bf34fe088f5717f711e7a95'
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

function Need($cmd, $msg) { if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) { throw $msg } }

# Requisitos
Need 'git' 'Falta git. Instala Git for Windows.'
Need 'claude' 'Falta Claude Code (comando claude no encontrado).'
$py = Get-Command py -ErrorAction SilentlyContinue
$pyExe = if ($py) { 'py' } else { 'python' }
Need $pyExe 'Falta Python 3.11+.'
$pv = & $pyExe -c 'import sys;print(f"{sys.version_info[0]}.{sys.version_info[1]}")'
if ([version]$pv -lt [version]'3.11') { throw "Python $pv es viejo; necesitas 3.11+." }
if ($UseDocker) { Need 'docker' 'Falta Docker Desktop.' } else {
  Need 'node' 'Falta Node 20+.'
  if ([int]((node -v).TrimStart('v').Split('.')[0]) -lt 20) { throw 'Node debe ser 20+.' }
}

# Git Bash o WSL para run_bash
$gitBin = $null
$gitExe = (Get-Command git).Source
$cand = Join-Path (Split-Path (Split-Path $gitExe)) 'usr\bin'
if (Test-Path (Join-Path $cand 'bash.exe')) { $gitBin = $cand }
$hasWsl = $false
if (Get-Command wsl -ErrorAction SilentlyContinue) { wsl.exe -l -q 2>$null | Out-Null; $hasWsl = ($LASTEXITCODE -eq 0) }
if (-not $gitBin -and -not $hasWsl) {
  throw 'No encuentro Git Bash ni WSL. El delegate necesita un shell tipo bash. Instala Git for Windows o WSL2 y vuelve a correr.'
}

# .env y config
if (-not (Test-Path .env)) { throw 'Crea .env desde .env.example con tus llaves primero.' }
if (-not (Test-Path bifrost\config.json)) { Copy-Item bifrost\config.example.json bifrost\config.json }
Get-Content .env | Where-Object { $_ -match '^[A-Z_]+=.+' } | ForEach-Object {
  $k,$v = $_ -split '=',2; [Environment]::SetEnvironmentVariable($k,$v,'Process') }
New-Item -ItemType Directory -Force bifrost-data | Out-Null
Copy-Item bifrost\config.json bifrost-data\config.json -Force

# Bifrost solo en 127.0.0.1
if ($UseDocker) {
  docker rm -f bifrost 2>$null | Out-Null
  docker run -d --name bifrost -p "127.0.0.1:${Port}:8080" -e APP_HOST=0.0.0.0 --env-file .env -v "${PWD}\bifrost-data:/app/data" maximhq/bifrost:v2.2.4 | Out-Null
} else {
  Start-Process npx.cmd -ArgumentList '-y','@maximhq/bifrost@1.6.3','-host','127.0.0.1','-port',"$Port",'-app-dir',"$Root\bifrost-data" -WindowStyle Minimized
}

# Delegate fijado + venv
if (-not (Test-Path delegate)) { git clone https://github.com/fegone/claude-code-delegate-local.git delegate }
git -C delegate fetch --quiet; git -C delegate checkout --quiet $Sha
& $pyExe -m venv .venv
& .\.venv\Scripts\python.exe -m pip install --quiet "fastmcp>=3.4.4" "httpx>=0.28.1"

# Comando de registro
$venvPy = Join-Path $Root '.venv\Scripts\python.exe'
$server = Join-Path $Root 'delegate\server.py'
$pathEnv = if ($gitBin) { "--env `"PATH=$gitBin;$env:PATH`"" } else { '' }
$cmd = "claude mcp add delegate-local --scope user --env DELEGATE_GATEWAY=bifrost --env DELEGATE_BIFROST_URL=http://127.0.0.1:$Port --env DELEGATE_BIFROST_VK_LOCAL= --env DELEGATE_BIFROST_VK_CODE= --env DELEGATE_LOCAL_MODEL=glm-coding-plan $pathEnv -- `"$venvPy`" `"$server`""
Set-Content windows\claude-mcp-add.txt $cmd
Write-Host "Listo. Pega este comando y reinicia Claude Code:`n`n$cmd"
