import 'package:dart_mcp/server.dart';
import 'package:nexsoft_server_shared/nexsoft_server_shared.dart';

import '../markdown.dart';
import '../mcp_response.dart';
import '../nexsoft_client.dart';
import '../server.dart';

/// Registers the tools only an admin key may use: deploying (Hot Reload, Restart) and reading the server's own log.
///
/// Offered only once `system.whoami` said the key is an admin (see [NexsoftMcpServer]); a `user` key never sees them,
/// and the server would refuse them anyway. They are the few things worth an AI's reach: everything else that
/// administers the server (API keys, secrets, limits, the schedule) stays on the dashboard.
void registerAdminTools(NexsoftMcpServer server, NexsoftClient client) {
  server.registerTool(
    Tool(
      name: 'nexsoft_hot_reload',
      description:
          'Pull the latest code and hot-reload the server (system.hotReload). Enough for plain Dart and shell-script '
          'changes; use nexsoft_restart for dependencies, generated code, a submodule pin, the plist or the dashboard.',
      inputSchema: Schema.object(properties: {}),
    ),
    (request) async => mcpText((await client.hotReload()).message),
  );

  server.registerTool(
    Tool(
      name: 'nexsoft_restart',
      description:
          'Pull, rebuild and restart the server (system.restart). Needed for dependencies, generated code, a '
          'nexsoft_server_shared pin bump, the plist and the dashboard source. Leave when_idle on so a build in '
          'flight is not interrupted.',
      inputSchema: Schema.object(
        properties: {
          'when_idle': Schema.bool(
            description:
                'Wait until no job is running or queued (default true)',
          ),
        },
      ),
    ),
    (request) async {
      final whenIdle = request.arguments?['when_idle'] as bool? ?? true;
      final result = await client.restart(RestartParams(whenIdle: whenIdle));
      return mcpText(result.message);
    },
  );

  server.registerTool(
    Tool(
      name: 'nexsoft_logs_tail',
      description:
          "Read the server's own log (admin.logs.tail): the newest lines, or a range with from_line/to_line. Use "
          'contains to find one thing in a log that is mostly polling.',
      inputSchema: Schema.object(
        properties: {
          'lines': Schema.int(
            description: 'How many lines (server default 200, cap 1000)',
          ),
          'source': UntitledSingleSelectEnumSchema(
            values: const ['server', 'novnc'],
            description: 'Which log (default server)',
          ),
          'from_line': Schema.int(description: 'First line, 1-based'),
          'to_line': Schema.int(description: 'Last line, inclusive'),
          'contains': Schema.string(
            description: 'Keep only lines containing this text',
          ),
        },
      ),
    ),
    (request) async {
      final args = request.arguments ?? const {};
      final result = await client.invokeAction('admin.logs.tail', {
        if (args['lines'] != null) 'lines': args['lines'],
        if (args['source'] != null) 'source': args['source'],
        if (args['from_line'] != null) 'from_line': args['from_line'],
        if (args['to_line'] != null) 'to_line': args['to_line'],
      });
      return mcpText(
        logLinesToMarkdown(result, contains: args['contains'] as String?),
      );
    },
  );
}
