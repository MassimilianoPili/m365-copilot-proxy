# Microsoft 365 Copilot OpenAI Proxy

A local proxy server that exposes your company's Microsoft 365 Copilot as an OpenAI-compatible API. No Azure app registration or admin consent required.

## How it works

The proxy connects to `substrate.office.com`, the same WebSocket API the M365 Copilot web UI uses, and wraps it in OpenAI-compatible HTTP endpoints. Authentication uses a short-lived token extracted from your signed-in browser session.

## Endpoints

- `GET /healthz` - service health plus token validity and remaining lifetime
- `GET /v1/token/status` - token validity, expiry time, and seconds remaining
- `GET /v1/models`
- `POST /v1/chat/completions` - OpenAI Chat Completions, streaming supported
- `POST /v1/responses` - OpenAI Responses API, streaming supported
- `POST /v1/messages` - Anthropic Messages API

## Constraints

- The M365 token usually expires in about 1 hour. The server can refresh it from a dedicated signed-in Edge window.
- Persistent Copilot sessions are supported when the client sends `X-M365-Session-Id` or uses the `m365-copilot:persist` model suffix.
- System prompts and conversation history are folded into the message as plain text.
- Tool calls and token usage are not supported.
- **Claude Code:** Agentic features such as file reading, bash, and code editing require tool use, which this proxy does not support. Use the proxy for general Q&A only; keep Claude Code on the real Anthropic API for coding tasks.

---

## Setup

### 1. Install

```powershell
uv sync
```

### 2. Start the server

```powershell
uv run copilot-openai-proxy serve
```

The server runs at `http://127.0.0.1:8000` by default.

On first run, `serve` opens a dedicated Edge profile at:

```text
%USERPROFILE%\.m365-copilot-openai-proxy\edge-profile
```

Sign in to M365 Copilot in that Edge window once. The server then tries to capture and save the Substrate token into `.env` automatically.

If the token is missing or expired, startup tries the same refresh path as pressing `r` in the server console. If Copilot has not created a Substrate WebSocket yet, click the Copilot message box and type one character. You do not need to send the message.

Custom host/port:

```powershell
uv run copilot-openai-proxy serve --host 127.0.0.1 --port 8000
```

---

## Token Refresh

Automatic refresh is on by default:

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

Manual fallback:

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

Token health:

```powershell
Invoke-RestMethod http://127.0.0.1:8000/healthz
Invoke-RestMethod http://127.0.0.1:8000/v1/token/status
```

Example response:

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

---

## Persistent Sessions

By default, requests are stateless from the Copilot side.

To reuse the same Copilot conversation across turns, send a stable session header:

```http
X-M365-Session-Id: my-work-session
```

Or use the persist model suffix:

```text
m365-copilot:persist
```

Header mode is better for coding tools if they support custom headers, because each tool/workspace can choose its own session id. If a client only supports changing the model name, `m365-copilot:persist` works, but clients that do not send a `user` field will share the same default persistent session until the proxy restarts.

---

## Using With AI Coding Tools

### OpenCode

```powershell
$env:OPENAI_BASE_URL = "http://127.0.0.1:8000"
$env:OPENAI_API_KEY = "dummy"
opencode
```

Select **OpenAI API** as the provider.

Use one of these models:

```text
m365-copilot
m365-copilot:persist
```

### Continue (VS Code extension)

Add to `~/.continue/config.json`:

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

### Any OpenAI-Compatible Client

| Setting | Value |
|---|---|
| Base URL | `http://127.0.0.1:8000/v1` |
| API Key | `dummy` |
| Model | `m365-copilot` or `m365-copilot:persist` |

---

## Manual API Examples

### Chat Completions

```powershell
$body = @{
  model = "m365-copilot"
  messages = @(
    @{ role = "system"; content = "Be concise." },
    @{ role = "user"; content = "hi" }
  )
} | ConvertTo-Json -Depth 10

$r = Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:8000/v1/chat/completions" -ContentType "application/json" -Body $body
$r.choices[0].message.content
```

### Persistent Session

```powershell
$body = @{
  model = "m365-copilot"
  messages = @(
    @{ role = "user"; content = "Remember this code word: sakura. Reply only OK." }
  )
} | ConvertTo-Json -Depth 10

Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:8000/v1/chat/completions" `
  -Headers @{ "X-M365-Session-Id" = "test1" } `
  -ContentType "application/json" `
  -Body $body
```

### Streaming

```powershell
$body = @{
  model = "m365-copilot"
  stream = $true
  messages = @(@{ role = "user"; content = "hi" })
} | ConvertTo-Json -Depth 10

Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:8000/v1/chat/completions" -ContentType "application/json" -Body $body
```

### Anthropic-Style

```powershell
$body = @{
  model = "m365-copilot"
  system = "Be concise."
  messages = @(@{ role = "user"; content = "hi" })
} | ConvertTo-Json -Depth 10

$r = Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:8000/v1/messages" -ContentType "application/json" -Body $body
$r.content[0].text
```

---

## Environment Variables

| Variable | Default | Description |
|---|---|---|
| `M365_ACCESS_TOKEN` | optional at startup | Bearer token from the browser WebSocket URL. If missing, startup capture can fill `.env`. |
| `M365_TIME_ZONE` | `Asia/Tokyo` | Optional. Time zone sent to Copilot. Usually no need to set this if `Asia/Tokyo` is correct. |
| `M365_MODEL_ALIAS` | `m365-copilot` | Optional. Model name returned by `/v1/models`. Usually no need to change this. |

---

## Token Automation Details

See [TOKEN_REFRESH.md](TOKEN_REFRESH.md) for how the Edge CDP refresh path works.
