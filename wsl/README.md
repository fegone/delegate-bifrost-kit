# Ruta recomendada: WSL2

El delegate corre `run_bash` con el shell del sistema; en Linux (WSL2) funciona como esta pensado. Todo dentro de la terminal de WSL (Ubuntu). Claude Code tambien debe estar instalado en WSL.

```bash
git clone https://github.com/fegone/delegate-bifrost-kit.git && cd delegate-bifrost-kit
cp .env.example .env && nano .env            # tus llaves
cp bifrost/config.example.json bifrost/config.json
set -a; . ./.env; set +a

# 1) Bifrost, solo en 127.0.0.1:4010 (elige una)
npx -y @maximhq/bifrost -host 127.0.0.1 -port 4010 -app-dir ./bifrost-data &
#  o Docker:
# docker run -d --name bifrost -p 127.0.0.1:4010:8080 -e APP_HOST=0.0.0.0 \
#   --env-file .env -v "$PWD/bifrost-data:/app/data" maximhq/bifrost
cp bifrost/config.json bifrost-data/config.json   # con npx; reinicia Bifrost despues

# 2) Delegate fijado al commit
git clone https://github.com/fegone/claude-code-delegate-local.git delegate
git -C delegate checkout 2c43bdb17402ec277bf34fe088f5717f711e7a95
python3 -m venv .venv && . .venv/bin/activate
pip install "fastmcp>=3.4.4" "httpx>=0.28.1"

# 3) Registrar en Claude Code
claude mcp add delegate-local --scope user \
  --env DELEGATE_GATEWAY=bifrost \
  --env DELEGATE_BIFROST_URL=http://127.0.0.1:4010 \
  --env DELEGATE_BIFROST_VK_LOCAL= \
  --env DELEGATE_BIFROST_VK_CODE= \
  --env DELEGATE_LOCAL_MODEL=glm-coding-plan \
  -- "$PWD/.venv/bin/python" "$PWD/delegate/server.py"
```

Reinicia Claude Code. Las virtual keys van vacias porque esta config no activa governance; si la activas, pon ahi tus llaves virtuales. Para el alias generico usa `generic-model`.
