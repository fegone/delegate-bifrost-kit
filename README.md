# delegate-bifrost-kit

Kit para correr el delegate de Claude Code (MCP `delegate-local`) contra **Bifrost oficial** (maximhq/bifrost) en vez de LiteLLM. Claude Code le manda tareas a modelos como GLM y DeepSeek, y Bifrost hace de puerta local en 127.0.0.1.

Delegate: https://github.com/fegone/claude-code-delegate-local (MIT). Este kit lo fija al commit `2c43bdb17402ec277bf34fe088f5717f711e7a95`.

## Requisitos
- Windows 11 (la ruta recomendada es WSL2)
- Node 20+ o Docker Desktop, para Bifrost
- Python 3.11+
- Git for Windows o WSL2
- Claude Code instalado

## Arranque rapido
1. Clona este repo y copia `.env.example` a `.env`; pon tus llaves (ZAI_API_KEY, DEEPSEEK_API_KEY).
2. Copia `bifrost/config.example.json` a `bifrost/config.json` y ajusta el slot generico si lo vas a usar.
3. WSL2 (recomendado): sigue `wsl/README.md`. Windows nativo: en PowerShell 7 corre `windows/install.ps1`.
4. Pega en Claude Code el comando `claude mcp add` que te imprime el instalador y reinicia Claude Code.
5. Pidele a Claude Code que use `delegate_to_local_agent` con el modelo `glm-coding-plan` y confirma que responde.

## Notas
- Bifrost queda solo en 127.0.0.1 (puerto 4010). No lo expongas.
- Las llaves van solo por variables de entorno, nunca dentro del JSON.
- El delegate ejecuta comandos de shell en tu carpeta de trabajo sin sandbox: usalo con agentes de confianza.
- Esquema de config de Bifrost: https://github.com/maximhq/bifrost/blob/main/transports/config.schema.json
