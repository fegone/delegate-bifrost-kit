# Windows nativo (PowerShell 7)

Necesitas: PowerShell 7, Python 3.11+, Git for Windows, y Node 20+ o Docker Desktop.

1. Clona el repo y crea `.env` desde `.env.example` con tus llaves. Copia `bifrost\config.example.json` a `bifrost\config.json`.
2. Abre PowerShell 7 en la carpeta del repo y corre `pwsh -File windows\install.ps1` (agrega `-UseDocker` para Docker en vez de npx).
3. El script revisa requisitos, levanta Bifrost en 127.0.0.1:4010, crea `.venv`, clona el delegate en el commit fijado, e imprime el comando `claude mcp add` (tambien lo guarda en `windows\claude-mcp-add.txt`).
4. Pega ese comando en una terminal normal y reinicia Claude Code.

Importante: el delegate lanza los comandos de `run_bash` con el shell por defecto de Windows (cmd.exe), no con bash. El instalador antepone el `usr\bin` de Git for Windows al PATH del MCP para tener grep, sed y demas, pero los comandos con sintaxis bash pueden fallar. Si vas a delegar trabajo de codigo, usa WSL2 (`wsl\README.md`).
