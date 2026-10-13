# delegate-bifrost-kit

Kit para correr el delegate de Claude Code (MCP `delegate-local`) contra **Bifrost oficial** (maximhq/bifrost) en vez de LiteLLM. Claude Code le manda tareas a modelos como GLM y DeepSeek, y Bifrost hace de puerta local en 127.0.0.1.

Delegate: https://github.com/fegone/claude-code-delegate-local (MIT). Este kit lo fija al commit `e43f506078fd95de82bbd3613aea0c789cefb05b`.

## Requisitos
- Windows 11 con WSL2 (Windows nativo no funciona, ver Novedades)
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

## Novedades del 2026-10-13
- El delegate sube de `916fff0` a `e43f506`. Se instala igual, con las mismas dependencias (`fastmcp`, `httpx`) y las mismas variables. No hay variables nuevas obligatorias.
- **Windows nativo no funciona.** El delegate importa `fcntl`, que solo existe en Linux y macOS, y en Windows nativo el MCP se cae al arrancar. Esto ya pasaba con el commit anterior. Usa WSL2 (`wsl/README.md`). `windows/install.ps1` queda en el repo, pero no lo uses hasta nuevo aviso.
- Hay seis herramientas nuevas que **puedes ignorar**. `submit_codex`, `poll_codex` y `cancel_codex` trabajan con el Codex CLI y un plan de ChatGPT. Sin el CLI responden "codex binary no encontrado". `submit_dsh`, `poll_dsh` y `cancel_dsh` necesitan un lanzador que este kit no trae y responden que la lista de modelos no está disponible. Ninguna impide que el delegate arranque. Lo tuyo sigue siendo `delegate_to_local_agent` y `delegate_batch`.
- `DELEGATE_GATEWAY_FILE` es opcional y no la necesitas. Sigue con `DELEGATE_GATEWAY=bifrost` como hasta ahora.
- Bifrost se queda en npm `1.6.3` y Docker `v2.2.4`, la versión más nueva con 14 días o más de publicada. La config de ejemplo no cambia. El comando npx ahora lleva `--transport-version v2.2.4` (detalle en Notas).

## Ids de modelo (ajusta al id vigente)
Los ids del lado del proveedor estan en `bifrost/config.example.json` (campo `aliases`: alias del delegate -> id real). Verificados contra la documentacion publica de cada proveedor el 2026-10-13 (sin cambios desde el 2026-09-30):
- Z.ai (GLM Coding Plan): `glm-5.3` y `glm-5.3-flash`. `glm-5.2`/`glm-5.1` siguen aceptandose pero Z.ai los redirige a `glm-5.3`.
- DeepSeek: `deepseek-v4-flash` y `deepseek-v4-pro`.
- Slot generico: `CAMBIA-ESTO-por-el-id-del-modelo`, pon el tuyo.
Los proveedores cambian ids sin avisar: si una llamada responde "model not found", ajusta el id vigente en `aliases` y reinicia Bifrost. El delegate siempre pide el alias (`glm-coding-plan`, `deepseek-v4-flash`...), nunca el id real.

## Como habla el delegate con Bifrost
- Con `DELEGATE_GATEWAY=bifrost` llama a `http://127.0.0.1:4010/litellm/v1/messages` (modelos GLM y similares, formato Anthropic) y `/litellm/v1/chat/completions` (DeepSeek y otros, formato OpenAI). Son las rutas de compatibilidad LiteLLM de Bifrost upstream.
- Bifrost resuelve el alias sin prefijo de proveedor: `glm-coding-plan` va al proveedor `anthropic` (Z.ai) y `deepseek-v4-flash` al proveedor `deepseek`. No hace falta escribir `provider/modelo`.
- `DELEGATE_BIFROST_VK_LOCAL` y `DELEGATE_BIFROST_VK_CODE` pueden ir **vacias**: esta config no activa governance. Si la activas, pon ahi tus virtual keys.
- `delegate_to_local_agent` necesita un agente: un `.md` con frontmatter en `<carpeta de trabajo>/.claude/agents/<nombre>.md` o en `~/.claude/agents/`. Sin agente no despacha nada.

## Prueba de punta a punta (Mac / Linux / WSL)
`tests/e2e_mac_linux.sh` levanta un proveedor falso en 127.0.0.1, Bifrost upstream apuntado a el (con llaves de mentira), el delegate fijado al commit, y despacha una tarea con `glm-coding-plan` y otra con `deepseek-v4-flash`. No usa llaves reales ni llama a ningun proveedor. Termina con `E2E PASS` o con un mensaje `FAIL`.
```bash
bash tests/e2e_mac_linux.sh
# opcional: DELEGATE_SRC=/ruta/a/un/clon/local  BIFROST_PORT=14010  MOCK_PORT=14011
```
Necesita bash, Python 3.11+, Node 20+, git y curl. Mata sus procesos y borra sus temporales al salir. La prueba no cubre Windows nativo (`windows/install.ps1`): ese script se comprobo solo con el parser de PowerShell.

## Notas
- Bifrost queda solo en 127.0.0.1 (puerto 4010). No lo expongas.
- Sin governance (virtual keys), cualquier programa de tu PC, o una página web abierta en tu navegador, puede usar la API y el panel de Bifrost en 127.0.0.1 y gastar tus llaves. Si la PC la usa más gente, activa governance en Bifrost y pon una virtual key en `DELEGATE_BIFROST_VK_CODE`.
- Las versiones van fijadas: npm `@maximhq/bifrost@1.6.3` con `--transport-version v2.2.4` y Docker `maximhq/bifrost:v2.2.4`. Sube de versión a propósito, no por accidente.
- El paquete npm `1.6.3` es solo un lanzador. Sin `--transport-version` baja el Bifrost más reciente, que el 2026-10-13 era v2.3.0. Esa versión exige virtual key y rompe esta config sin governance. Por eso el flag va en todos los comandos del kit. No lo quites.
- Las llaves van solo por variables de entorno, nunca dentro del JSON.
- El delegate ejecuta comandos de shell en tu carpeta de trabajo sin sandbox: usalo con agentes de confianza.
- Esquema de config de Bifrost: https://github.com/maximhq/bifrost/blob/main/transports/config.schema.json
