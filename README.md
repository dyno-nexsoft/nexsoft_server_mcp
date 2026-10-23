# nexsoft_server MCP Server

A Model Context Protocol (MCP) server for the `nexsoft_server` CI/build REST API.
Lets an AI assistant trigger builds, watch job state, and drive the build
queue directly from chat.

Written in Dart (`package:dart_mcp`), matching the rest of the org's stack —
this used to be TypeScript; see git history before the v3.0.0 rewrite for
that implementation.

## Features

**What a key sees depends on its role.** An AI client can be talked into
anything a tool lets it do, so a key with the `user` role (`read` + `invoke`)
gets only tools that read and run jobs, and no tool that administers
`nexsoft_server` or writes anywhere else (Zentao reports, GitLab reviews,
deleting history). At start-up the server asks `nexsoft_server` who the key is
(`system.whoami`); for an `admin` key it adds the three admin tools below and
tells the client the tool list changed. A key that cannot be identified keeps
the plain set. `nexsoft_invoke_action` takes only the names in
[`lib/src/allowed_actions.dart`](lib/src/allowed_actions.dart), plus the admin
ones for an admin key. Everything else that administers the server (API keys,
secrets, limits, the schedule, the AI provider, cron) is the dashboard's.

| Tool                          | Description                                                |
| ------------------------------ | ----------------------------------------------------------- |
| `nexsoft_health`                  | Liveness probe (no auth)                                   |
| `nexsoft_status`                  | Queue state, uptime, running/queued jobs                   |
| `nexsoft_list_actions`            | The actions this server may call                           |
| `nexsoft_describe_action`         | Full parameter schema for one of them                       |
| `nexsoft_list_jobs`               | List jobs, newest first, filterable by state                |
| `nexsoft_get_job`                 | Full detail of one job                                      |
| `nexsoft_get_job_log`             | Poll a job's build log by byte offset                        |
| `nexsoft_cancel_job`              | Cancel a job                                                 |
| `nexsoft_promote_job`             | Promote a queued job into the parallel lane                 |
| `nexsoft_retry_job`               | Re-invoke the action recorded on a finished job              |
| `nexsoft_ci_build`                | Friendly alias for the `ci.build` action                     |
| `nexsoft_ci_gen`                  | Friendly alias for the `ci.gen` action                       |
| `nexsoft_ci_interaction`          | Friendly alias for the `ci.interaction` action               |
| `nexsoft_ci_reposts`              | Friendly alias for the `ci.reposts` action                   |
| `nexsoft_ci_replace`              | Friendly alias for the `ci.replace` action                   |
| `nexsoft_autocomplete_branches`   | Branch names for a build's repositories                      |
| `nexsoft_zentao_report_get`       | View a Zentao daily report task                              |
| `nexsoft_schedule_get`            | Working calendar, days off and every scheduled job with its next run |
| `nexsoft_limits_get`              | The admin limits: retention, timeouts, AI settings           |
| `nexsoft_ai_provider_get`         | The AI provider (Gemini or Groq) and failover                |
| `nexsoft_invoke_action`           | Generic dispatch, for the allowed actions only               |
| `nexsoft_hot_reload` (admin key)  | Pull and hot-reload the server                               |
| `nexsoft_restart` (admin key)     | Pull, rebuild and restart; `when_idle` defaults to true      |
| `nexsoft_logs_tail` (admin key)   | Read the server log: newest lines, a range, or lines containing a text |

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
every admin action whatever is sent. An `admin` key also gets Hot Reload,
Restart and the log tail: keep it for the one MCP you drive deploys from. The
key is the boundary, the tool list a convenience. A key an owner creates starts
as `admin`, so an admin edits its scopes down to `read` and `invoke`
(`admin.apiKeys.edit`, or the dashboard's API keys screen) before it goes
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
dart test
dart run bin/nexsoft_server_mcp.dart   # runs the server directly against stdio
```

### Project structure

```
bin/
└── nexsoft_server_mcp.dart      # Entry point — connects the server to stdio

lib/src/
├── server.dart               # NexsoftMcpServer: registers every tool group
├── nexsoft_client.dart           # http client: API key header, selective GET cache
├── allowed_actions.dart      # the only actions this server calls
├── job_formatter.dart        # jobToMarkdown · jobsToMarkdown
├── mcp_response.dart         # mcpText
└── tools/
    ├── meta_tool.dart         # nexsoft_health · nexsoft_status · nexsoft_list_actions · nexsoft_describe_action
    ├── job_tool.dart          # nexsoft_list_jobs · nexsoft_get_job · nexsoft_get_job_log · nexsoft_cancel_job · nexsoft_promote_job · nexsoft_retry_job
    ├── build_tool.dart        # nexsoft_ci_build · nexsoft_ci_gen · nexsoft_ci_interaction · nexsoft_ci_reposts · nexsoft_ci_replace · nexsoft_autocomplete_branches
    ├── zentao_tool.dart       # nexsoft_zentao_report_get
    ├── config_tool.dart       # nexsoft_schedule_get · nexsoft_limits_get · nexsoft_ai_provider_get
    └── action_tool.dart       # nexsoft_invoke_action, limited to allowed_actions.dart
```
