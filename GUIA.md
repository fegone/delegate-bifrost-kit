# Guía del delegate con Bifrost

Esta guía es para Edgar y su equipo. Explica para qué sirve el delegate, cómo se conecta cada modelo y cómo agregar uno nuevo. La instalación paso a paso está en `macos/README.md` (Mac) y `wsl/README.md` (Windows con WSL2).

## Para qué sirve

Claude Code es el que manda. Tú le hablas a Claude, y Claude decide el plan, revisa el resultado y te responde. El delegate es un servidor MCP que le da a Claude una forma de pasarle trabajo a otro modelo: una tarea de código cerrada, una búsqueda en el repo o un lote de tareas iguales.

Sirve para tres cosas.

1. Gastar menos cuota de Claude en trabajo mecánico.
2. Usar el modelo que mejor rinde para cada tipo de tarea.
3. Correr varias tareas en paralelo mientras Claude sigue con lo suyo.

Claude siempre revisa lo que vuelve. El otro modelo hace el trabajo y Claude decide si sirve.

En la práctica le dices a Claude algo como "usa el delegate con deepseek-v4-flash para escribir los tests de este archivo". Claude llama a la herramienta `delegate_to_local_agent`, el modelo trabaja en tu carpeta con permiso para leer, escribir y correr comandos, y al final Claude ve el resultado.

## Los tres caminos

Cada modelo entra por uno de estos caminos.

| Camino | Modelos | Cómo se paga | Pasa por Bifrost |
|---|---|---|---|
| Llave de API | DeepSeek, GLM de Z.ai, OpenRouter, Gemini por API, cualquier proveedor compatible con OpenAI | Por uso, con la llave de cada proveedor | Sí |
| Suscripción con su propio CLI | GPT por Codex con el plan de ChatGPT | La suscripción de ChatGPT | No |
| Claude | Claude mismo | Tu cuenta de Claude | No aplica |

**Por qué unos van por Bifrost y otros no.** Bifrost es una puerta local en 127.0.0.1 que guarda las llaves de API, les pone límites y le da al delegate una sola dirección para todos los proveedores. Solo funciona con llaves de API. Una suscripción como la de ChatGPT no trae llave, trae un inicio de sesión dentro de su CLI. Por eso GPT va directo por el CLI de Codex (`delegate_to_codex`, `submit_codex`) y no toca Bifrost. Si algún día usan GPT con una llave de API de OpenAI, esa sí iría por Bifrost, pero se paga aparte de la suscripción.

**Claude no se delega.** Claude Code ya es el que orquesta con tu cuenta. Meter la suscripción de Claude detrás de un proxy no está permitido por los términos de Anthropic.

## Gemini y Antigravity

Hay dos formas de usar Gemini con el delegate.

**Con llave de API.** Se crea una llave en Google AI Studio y se agrega Gemini como proveedor en Bifrost (sección siguiente). Se paga por uso y no entra en la suscripción de Google.

**Con la suscripción, por el CLI de Antigravity (`agy`).** Desde el commit `ff4b4a5` (este kit fija `25dbf8d`) el delegate trae `delegate_to_gemini`, `submit_gemini`, `poll_gemini` y `cancel_gemini`, que corren Gemini 3.8 Flash (low, medium o high) con tu plan de Google.

1. Instala el CLI con `brew install --cask antigravity-cli`. Revisa la firma con `spctl -a -vv -t open --context context:primary-signature "$(readlink -f "$(which agy)")"`. En nuestra Mac la versión 1.3.3 salió firmada por Google pero sin notarizar y macOS la bloqueó al abrirla. En la Mac de Edgar salió notarizada. Si te la bloquea, la decisión de abrirla es tuya.
2. Corre `agy` una vez en una terminal y entra con tu cuenta de Google. `agy models` tiene que listar `gemini-3.8-flash-low`.
3. Agrega `DELEGATE_GEMINI_ALLOW_DANGER=1` al env del MCP y reinicia Claude Code. Sin esa variable las herramientas de Gemini se niegan a correr.

Gemini corre dentro de una jaula de macOS (`sandbox-exec`). Solo puede leer la carpeta de trabajo, `~/.gemini`, el llavero en solo lectura y las rutas del sistema. No ve el resto de `$HOME`, `/Users` ni `/Volumes`, y no puede abrir el navegador. Lo que sigue abierto es la red de salida y el programa `security` del llavero.

Dos límites de `agy`:

- En modo `-p` un solo comando rechazado corta toda la corrida.
- Por SSH no funciona, porque la sesión de Google vive en el llavero de la sesión gráfica. Úsalo en la Mac con sesión abierta.

## Agregar otro modelo por llave de API

Son cuatro pasos. El ejemplo agrega Gemini, y para otro proveedor solo cambian el nombre, la llave y el id del modelo.

**1. La llave va en `.env`, nunca en el JSON.**

```bash
GEMINI_API_KEY=pon-aqui-tu-llave
```

**2. El proveedor va en `bifrost/config.json`, dentro de `providers`.**

```json
"gemini": {
  "keys": [
    {
      "name": "gemini",
      "value": "env.GEMINI_API_KEY",
      "weight": 1,
      "models": ["*"],
      "aliases": {
        "gemini-flash": "gemini-3.8-flash"
      }
    }
  ],
  "network_config": { "default_request_timeout_in_seconds": 300, "max_retries": 2 }
}
```

El alias de la izquierda es el nombre que usa Claude. El de la derecha es el id real del proveedor, que hay que confirmar en su documentación porque cambia sin aviso. Para un proveedor compatible con OpenAI que Bifrost no trae de fábrica, copien el bloque `generic-openai` de `bifrost/config.example.json` y cambien `base_url`.

**3. El nombre del alias decide el formato.** El delegate manda por formato OpenAI (`/chat/completions`) los alias que empiezan con `deepseek-`, `openai-`, `gpt-`, `qwen-`, `minimax-`, `moonshot-`, `kimi-`, `grok-` o `mimo-`. Todo lo demás va por formato Anthropic (`/messages`) y Bifrost lo traduce al proveedor. Si un modelo compatible con OpenAI responde raro, pónganle al alias el prefijo `openai-` (por ejemplo `openai-mi-modelo`).

**4. Reinicien Bifrost y prueben.** Después de reiniciar, díganle a Claude "usa el delegate con el modelo gemini-flash para listar los archivos de esta carpeta". Si el proveedor responde "model not found", el id real está mal. Si responde 401, la llave está mal o no cargó desde `.env`.

El delegate no tiene lista cerrada de modelos para `delegate_to_local_agent`. Cualquier alias que Bifrost conozca sirve.

## GPT con Codex

1. Instalen el CLI de Codex (`brew install codex` en Mac) e inicien sesión con `codex login` usando la cuenta de ChatGPT.
2. Reinicien Claude Code.
3. Díganle a Claude "usa Codex para esta tarea". Claude llama a `delegate_to_codex`, o a `submit_codex` y `poll_codex` si la tarea es larga.

No hace falta tocar Bifrost para esto.

## Cuidados

- Bifrost escucha solo en 127.0.0.1. No lo expongan a la red.
- Sin virtual keys, cualquier programa de esa máquina, o una página abierta en el navegador, puede usar Bifrost y gastar sus llaves. Si la máquina la usa más gente, activen governance en Bifrost y pongan la virtual key en `DELEGATE_BIFROST_VK_CODE`.
- El delegate corre comandos en la carpeta de trabajo sin sandbox. Úsenlo solo en repos y con modelos de confianza.
- `delegate_to_local_agent` y `delegate_batch` no tienen sandbox. `run_bash` corre con tu usuario y puede leer todo tu `$HOME`, incluidos `~/.ssh` y `~/.codex/auth.json`, y lo que lea se va al proveedor del modelo. Úsalos solo en repos de confianza y nunca con datos de clientes ni de pacientes. Gemini por `agy` es la excepción, porque corre en su jaula.
- **Failover automático.** Si las 6 plazas de un modelo están ocupadas, el delegate pasa la tarea a otro de su cadena, por ejemplo de `glm-coding-plan` a `qwen-3-8-max` y luego a DeepSeek, sin preguntarte. El resultado dice qué modelo la sirvió. Los modelos locales y Codex nunca cambian de modelo.
- Windows nativo no funciona. En Windows usen WSL2.
