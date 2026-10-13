# Ruta para macOS (Apple Silicon)

Todo corre en tu Mac, en la Terminal. Bifrost queda solo en 127.0.0.1.

## 1. Programas que necesitas
Instálalos con Homebrew.
```bash
brew install python@3.12 node git
```
Necesitas Python 3.11 o más nuevo, Node 20 o más nuevo y git. Claude Code también tiene que estar instalado (comando `claude`).

## 2. Descarga el kit y pon tus llaves
```bash
git clone https://github.com/fegone/delegate-bifrost-kit.git && cd delegate-bifrost-kit
cp .env.example .env && nano .env
cp bifrost/config.example.json bifrost/config.json
```
Las llaves van solo en `.env`, nunca dentro del JSON. Nunca subas `.env` a git.

## 3. Instala el delegate
```bash
bash macos/install.sh
```
El script clona el delegate en la carpeta `delegate/` fijado al commit `e43f506078fd95de82bbd3613aea0c789cefb05b`, crea `.venv/` e instala `fastmcp` y `httpx`. No pide sudo, no lee tus llaves y se puede correr varias veces. Al final imprime el comando `claude mcp add` listo para pegar (paso 5).

Si prefieres hacerlo a mano, estos son los pasos.
```bash
git clone https://github.com/fegone/claude-code-delegate-local.git delegate
git -C delegate checkout e43f506078fd95de82bbd3613aea0c789cefb05b
python3 -m venv .venv && . .venv/bin/activate
pip install "fastmcp>=3.4.4" "httpx>=0.28.1"
```

## 4. Arranca Bifrost
```bash
mkdir -p bifrost-data && cp bifrost/config.json bifrost-data/config.json
set -a; . ./.env; set +a
npx -y @maximhq/bifrost@1.6.3 --transport-version v2.2.4 -host 127.0.0.1 -port 4010 -app-dir ./bifrost-data
```
Déjalo corriendo en esa terminal (o usa el LaunchAgent de más abajo). No quites `--transport-version v2.2.4`, porque sin él npm baja Bifrost v2.3.0, que exige virtual key y rompe esta config.

Para comprobar que responde, corre en otra terminal `curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:4010/`. Debe dar 200.

## 5. Registra el delegate
Hazlo desde la carpeta del kit.
```bash
claude mcp add delegate-local --scope user \
  --env DELEGATE_GATEWAY=bifrost \
  --env DELEGATE_BIFROST_URL=http://127.0.0.1:4010 \
  --env DELEGATE_BIFROST_VK_LOCAL= \
  --env DELEGATE_BIFROST_VK_CODE= \
  --env DELEGATE_LOCAL_MODEL=glm-coding-plan \
  -- "$PWD/.venv/bin/python" "$PWD/delegate/server.py"
```
Las virtual keys van vacías porque esta config no activa virtual keys. Reinicia Claude Code.

## 6. Prueba
El delegate necesita un archivo `.md` con frontmatter, ya sea en `.claude/agents/` de tu carpeta de trabajo o en `~/.claude/agents/`. Luego pídele a Claude Code que use `delegate_to_local_agent` con el modelo `glm-coding-plan` y una tarea corta. Si responde, quedó. Para probar todo el camino sin llaves reales corre `bash tests/e2e_mac_linux.sh`.

## Opcional, Bifrost siempre encendido con un LaunchAgent
Crea `~/Library/LaunchAgents/com.tuusuario.bifrost.plist`. Cambia `RUTA` por la ruta completa de tu carpeta del kit (`pwd` dentro de ella).
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>com.tuusuario.bifrost</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>-c</string>
    <string>set -a; . RUTA/.env; set +a; exec npx -y @maximhq/bifrost@1.6.3 --transport-version v2.2.4 -host 127.0.0.1 -port 4010 -app-dir RUTA/bifrost-data</string>
  </array>
  <key>EnvironmentVariables</key>
  <dict><key>PATH</key><string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string></dict>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>StandardOutPath</key><string>RUTA/bifrost.log</string>
  <key>StandardErrorPath</key><string>RUTA/bifrost.log</string>
</dict>
</plist>
```
Para cargarlo y para quitarlo usa estos comandos.
```bash
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.tuusuario.bifrost.plist
launchctl bootout gui/$(id -u)/com.tuusuario.bifrost
```
Si cambias `.env` o `config.json`, haz `bootout` y `bootstrap` otra vez. Si ya tienes Bifrost corriendo en una terminal, ciérralo antes, porque los dos usan el puerto 4010.

## Cuidado
- El delegate ejecuta comandos de shell en tu carpeta de trabajo sin sandbox. Úsalo solo con configuraciones en las que confíes.
- Sin virtual keys, cualquier programa de tu Mac puede usar la API de Bifrost en 127.0.0.1 y gastar tus llaves. No expongas el puerto.
