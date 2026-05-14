# Microsoft 365 Copilot OpenAI Proxy

Use Microsoft 365 Copilot through OpenAI-compatible clients, local scripts, and coding tools.

This project runs a local FastAPI proxy that talks to the same `substrate.office.com` WebSocket API used by the M365 Copilot web UI, then exposes it as OpenAI-style HTTP endpoints.

No Azure app registration. No admin consent. Sign in with your normal M365 Copilot browser session.

## Why Use This

- Use M365 Copilot from OpenAI-compatible clients
- Works with your existing signed-in Copilot web session
- Runs locally on `127.0.0.1` by default
- Auto-captures and refreshes the short-lived browser token
- Supports persistent Copilot sessions across turns
- Supports OpenAI Chat Completions, OpenAI Responses, and Anthropic Messages style requests

## Quick Start

```powershell
uv sync
uv run copilot-openai-proxy serve
```

The server starts at:

```text
http://127.0.0.1:8000
```

On first run, the proxy opens a dedicated Edge window. Sign in to M365 Copilot there once. The proxy will capture the required Substrate token and write it to `.env`.

The dedicated Edge profile is stored at:

```text
%USERPROFILE%\.m365-copilot-openai-proxy\edge-profile
```

If startup says it is waiting for a token, click the Copilot message box and type one character. You do not need to send the message.

## Test It

```powershell
$body = @{
  model = "m365-copilot"
  messages = @(
    @{ role = "user"; content = "Say hello in one short sentence." }
  )
} | ConvertTo-Json -Depth 10

$r = Invoke-RestMethod `
  -Method Post `
  -Uri "http://127.0.0.1:8000/v1/chat/completions" `
  -ContentType "application/json" `
  -Body $body

$r.choices[0].message.content
```

## Connect A Client

Use these settings for any OpenAI-compatible client:

| Setting | Value |
|---|---|
| Base URL | `http://127.0.0.1:8000/v1` |
| API Key | `dummy` |
| Model | `m365-copilot` |
| Persistent model | `m365-copilot:persist` |

### OpenCode

```powershell
$env:OPENAI_BASE_URL = "http://127.0.0.1:8000"
$env:OPENAI_API_KEY = "dummy"
opencode
```

Select **OpenAI API** as the provider, then use:

```text
m365-copilot
```

For persistent Copilot-side conversation memory:

```text
m365-copilot:persist
```

### Continue

Add this to `~/.continue/config.json`:

```json
{
  "models": [
    {
      "title": "M365 Copilot",
      "provider": "openai",
      "model": "m365-copilot:persist",
      "apiBase": "http://127.0.0.1:8000/v1",
      "apiKey": "dummy"
    }
  ]
}
```

### Claude Code

```powershell
$env:ANTHROPIC_BASE_URL = "http://127.0.0.1:8000"
$env:ANTHROPIC_API_KEY = "dummy"
claude
```

Claude Code note: this proxy does not implement tool use. It can answer general prompts, but agentic features such as file reading, bash, and code editing still require the real Anthropic API.

## Persistent Sessions

By default, requests are stateless from the Copilot side.

To reuse the same Copilot conversation across turns, send a stable header:

```http
X-M365-Session-Id: my-work-session
```

Or use the model suffix:

```text
m365-copilot:persist
```

Header mode is better when your client supports custom headers, because each workspace or coding-agent session can choose its own id. If your client only lets you change the model name, use `m365-copilot:persist`.

If a client uses `m365-copilot:persist` without sending a `user` field, all requests share one default persistent session until the proxy restarts.

## Token Refresh

M365 Copilot browser tokens usually expire in about 1 hour. The proxy refreshes them from the dedicated signed-in Edge window.

Auto-refresh is on by default:

```powershell
uv run copilot-openai-proxy serve
```

Useful controls:

```powershell
uv run copilot-openai-proxy serve --refresh-before-seconds 300
uv run copilot-openai-proxy serve --no-auto-refresh
uv run copilot-openai-proxy serve --no-capture-on-start
uv run copilot-openai-proxy serve --no-launch-edge
```

You can also press `r` in the server console to refresh the token manually.

### Manual Fallback

```powershell
uv run copilot-openai-proxy set-token
```

Then paste a fresh Substrate WebSocket URL:

1. Open the signed-in M365 Copilot Edge window.
2. Open DevTools (`F12`) -> **Network** tab.
3. Filter by `substrate`.
4. Click the WebSocket entry.
5. Go to **Headers** -> right-click the **Request URL** -> **Copy link address**.
6. Paste it into the terminal.

The command extracts `access_token` automatically and writes it to `.env`.

## Token Health

```powershell
Invoke-RestMethod http://127.0.0.1:8000/healthz
Invoke-RestMethod http://127.0.0.1:8000/v1/token/status
```

Example:

```json
{
  "status": "ok",
  "token": {
    "valid": true,
    "expires_at": "2026-05-14T02:50:53+00:00",
    "seconds_remaining": 4200
  }
}
```

## API Endpoints

| Endpoint | Description |
|---|---|
| `GET /healthz` | Service health plus token status |
| `GET /v1/token/status` | Token validity, expiry time, and seconds remaining |
| `GET /v1/models` | OpenAI-compatible model list |
| `POST /v1/chat/completions` | OpenAI Chat Completions, streaming supported |
| `POST /v1/responses` | OpenAI Responses API, streaming supported |
| `POST /v1/messages` | Anthropic Messages API style endpoint |

## More Examples

### Streaming

```powershell
$body = @{
  model = "m365-copilot"
  stream = $true
  messages = @(@{ role = "user"; content = "hi" })
} | ConvertTo-Json -Depth 10

Invoke-RestMethod `
  -Method Post `
  -Uri "http://127.0.0.1:8000/v1/chat/completions" `
  -ContentType "application/json" `
  -Body $body
```

### Persistent Session

```powershell
$body = @{
  model = "m365-copilot"
  messages = @(
    @{ role = "user"; content = "Remember this code word: sakura. Reply only OK." }
  )
} | ConvertTo-Json -Depth 10

Invoke-RestMethod `
  -Method Post `
  -Uri "http://127.0.0.1:8000/v1/chat/completions" `
  -Headers @{ "X-M365-Session-Id" = "test1" } `
  -ContentType "application/json" `
  -Body $body
```

### Anthropic-Style Messages

```powershell
$body = @{
  model = "m365-copilot"
  system = "Be concise."
  messages = @(@{ role = "user"; content = "hi" })
} | ConvertTo-Json -Depth 10

$r = Invoke-RestMethod `
  -Method Post `
  -Uri "http://127.0.0.1:8000/v1/messages" `
  -ContentType "application/json" `
  -Body $body

$r.content[0].text
```

## Security Notes

- The proxy listens on `127.0.0.1` by default.
- The browser token is stored locally in `.env`.
- `.env`, `.venv/`, and Python cache files are ignored by Git.
- The proxy does not send your token to any external service besides Microsoft 365 Copilot's own `substrate.office.com` endpoint.
- Anyone who can read your `.env` can use the token until it expires. Treat it like a secret.

## Environment Variables

Most users only need `.env` after the proxy captures a token.

| Variable | Default | Description |
|---|---|---|
| `M365_ACCESS_TOKEN` | optional at startup | Browser WebSocket token. If missing, startup capture can fill `.env`. |
| `M365_TIME_ZONE` | `Asia/Tokyo` | Optional. Time zone sent to Copilot. Usually no need to set this if `Asia/Tokyo` is correct. |
| `M365_MODEL_ALIAS` | `m365-copilot` | Optional. Model name returned by `/v1/models`. Usually no need to change this. |

## Limitations

- This is an unofficial local proxy over the browser-facing M365 Copilot API.
- Token refresh depends on a signed-in Edge profile.
- Tool calls are not supported.
- Token usage numbers are placeholders.
- System prompts and prior conversation history are translated into plain text context.

## License

Apache License 2.0. See [LICENSE](LICENSE).

## Token Automation Details

See [TOKEN_REFRESH.md](TOKEN_REFRESH.md) for the deeper Edge CDP refresh notes and alternatives.

## Support

If this project saves you time, please consider giving it a GitHub star. It helps other people find the repo.

[![Star History Chart](https://api.star-history.com/svg?repos=kuchris/m365-copilot-openai-proxy&type=Date)](https://www.star-history.com/#kuchris/m365-copilot-openai-proxy&Date)
