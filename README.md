# nexsoft_server MCP Server

A Model Context Protocol (MCP) server for the `nexsoft_server` CI/build REST API.
Lets an AI assistant trigger builds, watch job state, and drive the build
queue directly from chat.

Written in Dart (`package:dart_mcp`), matching the rest of the org's stack —
this used to be TypeScript; see git history before the v3.0.0 rewrite for
that implementation.

Runs on **Dart 3.9 or newer** (Flutter 3.35 or newer), so it works with the SDK
a Flutter project already has; a compiled executable needs no SDK at all.

## Features

**The tools are the API Swagger shows.** Every key gets one tool per
documented call, and nothing else; a key with the `admin` role also gets three
more that reach any other action. The server asks `nexsoft_server` who the key
is when it starts (`system.whoami`), adds those tools for an admin and tells the
client the tool list changed. A key that cannot be identified keeps the plain
set.

| Tool                     | Swagger call                          |
| ------------------------- | -------------------------------------- |
| `nexsoft_health`          | `GET /health` (no auth)                |
| `nexsoft_status`          | `GET /status`                          |
| `nexsoft_list_jobs`       | `GET /jobs`                            |
| `nexsoft_get_job`         | `GET /jobs/{id}`                       |
| `nexsoft_get_job_log`     | `GET /jobs/{id}/log` (by byte offset)  |
| `nexsoft_cancel_job`      | `POST /jobs/{id}/cancel`               |
| `nexsoft_promote_job`     | `POST /jobs/{id}/promote`              |
| `nexsoft_retry_job`       | `POST /jobs/{id}/retry`                |
| `nexsoft_ci_build`        | `POST /builds`                         |
| `nexsoft_ci_reposts`      | `POST /reposts`                        |
| `nexsoft_ci_interaction`  | `POST /interactions`                   |

**Admin key only**

| Tool                        | What it does                                           |
| ---------------------------- | ------------------------------------------------------- |
| `nexsoft_list_actions`       | Every action the server has                            |
| `nexsoft_describe_action`    | Parameters of one action                               |
| `nexsoft_invoke_action`      | Calls one by name with its params                      |

**Design notes:**
- No login step: auth is a static API key sent as `X-API-Key` on every request.
- GET responses are cached only for `/actions` (rarely changes, 5 min TTL);
  job/status endpoints always hit the network so state stays current.
- No SSE tool: an MCP tool call is request/response, not a long-lived stream.
  Real-time log tailing is exposed instead as `nexsoft_get_job_log`'s
  offset-based polling — call it again with the returned `nextOffset`.
- `nexsoft_server` is LAN-only, not published to the public internet. This MCP
  server must run somewhere that can reach it directly — e.g. on the same
  host, pointing `NEXSOFT_SERVER_BASE_URL` at `http://localhost:8080/api/v1` —
  or over a VPN/LAN connection to it.
- Wire types (`Job`, `Health`, `SystemStatus`, `ActionSchema`, ...) come from
  [`nexsoft_server_shared`](https://github.com/dyno-nexsoft/nexsoft_server_shared),
  the same package the backend and dashboard use — this is a third consumer
  of it, not a fourth hand-copied set of models.

## Configuration

Set these as real OS environment variables (not `--dart-define`) — via a
`.env` you source before running, or the MCP client's own `env` block:

```env
NEXSOFT_SERVER_BASE_URL=https://<nexsoft-server-host>/api/v1
NEXSOFT_SERVER_API_KEY=<secret>
```

**Choose the key for what the client may do.** A `user` key (`read` + `invoke`)
is the one to hand to anyone else: the tools above, and `nexsoft_server` refuses
every admin action whatever is sent. An `admin` key also gets the three
admin-only tools: keep it for the one client you drive the server from. The key
is the boundary, the tool list a convenience. A key an owner creates starts as
`admin`, so an admin edits its scopes down to `read` and `invoke` before it goes
anywhere else.

## MCP Client Integration

This server communicates via stdio transport. Requires a local checkout with
`nexsoft_server_shared` available as a sibling directory (`../nexsoft_server_shared`)
— the normal case when this repo is checked out as a submodule of the parent
`nexsoft_server` repo, since that's where both this repo and `nexsoft_server_shared`
already live side by side.

```json
{
  "mcpServers": {
    "nexsoft_server": {
      "command": "dart",
      "args": ["run", "/path/to/nexsoft_server/nexsoft_server_mcp/bin/nexsoft_server_mcp.dart"],
      "env": {
        "NEXSOFT_SERVER_BASE_URL": "https://<nexsoft-server-host>/api/v1",
        "NEXSOFT_SERVER_API_KEY": "<secret>"
      }
    }
  }
}
```

Or point at a compiled executable (built via `dart compile exe
bin/nexsoft_server_mcp.dart -o nexsoft_server_mcp`, or downloaded from a
[release](../../releases)) instead of `dart run`, for faster startup:

```json
{
  "mcpServers": {
    "nexsoft_server": {
      "command": "/path/to/nexsoft_server_mcp",
      "env": {
        "NEXSOFT_SERVER_BASE_URL": "https://<nexsoft-server-host>/api/v1",
        "NEXSOFT_SERVER_API_KEY": "<secret>"
      }
    }
  }
}
```

### opencode

[opencode](https://opencode.ai)'s `opencode.jsonc` uses a different shape for
local MCP servers: `type: "local"` is required, `command` is a single array
(the executable and every argument combined, not split into `command`+`args`),
and the env block is called `environment`, not `env`:

```jsonc
{
  "mcp": {
    "nexsoft_server": {
      "type": "local",
      "command": [
        "dart",
        "run",
        "/path/to/nexsoft_server/nexsoft_server_mcp/bin/nexsoft_server_mcp.dart"
      ],
      "environment": {
        "NEXSOFT_SERVER_BASE_URL": "https://<nexsoft-server-host>/api/v1",
        "NEXSOFT_SERVER_API_KEY": "<secret>"
      }
    }
  }
}
```

## Development

```bash
dart pub get
dart analyze
dart run bin/nexsoft_server_mcp.dart   # runs the server directly against stdio
```

### Project structure

```
bin/
└── nexsoft_server_mcp.dart      # Entry point — connects the server to stdio

lib/src/
├── server.dart               # NexsoftMcpServer: registers the tools, adds the admin ones for an admin key
├── nexsoft_client.dart           # http client: API key header, selective GET cache
├── job_formatter.dart        # jobToMarkdown · jobsToMarkdown
├── mcp_response.dart         # mcpText
└── tools/
    ├── meta_tool.dart         # nexsoft_health · nexsoft_status
    ├── job_tool.dart          # nexsoft_list_jobs · nexsoft_get_job · nexsoft_get_job_log · nexsoft_cancel_job · nexsoft_promote_job · nexsoft_retry_job
    ├── build_tool.dart        # nexsoft_ci_build · nexsoft_ci_interaction · nexsoft_ci_reposts
    └── admin_tool.dart        # admin key only: nexsoft_list_actions · nexsoft_describe_action · nexsoft_invoke_action
```
