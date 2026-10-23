import 'package:dart_mcp/server.dart';
import 'package:nexsoft_server_shared/nexsoft_server_shared.dart' as shared;

import '../allowed_actions.dart';
import '../job_formatter.dart';
import '../markdown.dart';
import '../mcp_response.dart';
import '../nexsoft_client.dart';
import '../server.dart';

bool _looksLikeJob(Map<String, dynamic> data) =>
    data['state'] is String && data['action_name'] is String;

/// Registers the generic dispatch tool, mirroring `POST /actions/{name}`, for
/// an action without a dedicated tool. Only the names in [allowedActions]:
/// anything else is refused here, before a request is made.
/// Use `nexsoft_describe_action` first to see the param schema for a given name.
void registerActionTools(NexsoftMcpServer server, NexsoftClient client) {
  server.registerTool(
    Tool(
      name: 'nexsoft_invoke_action',
      description:
          'Generic dispatch: invoke one of the actions nexsoft_list_actions '
          'shows (reading, and running or cancelling jobs) by name. Returns '
          "the job for kind='job' actions, the result otherwise.",
      inputSchema: Schema.object(
        properties: {
          'name': Schema.string(
            description: "Action name, e.g. 'ci.build', 'system.status'",
          ),
          'params': Schema.object(
            description:
                'Action-specific parameters, per nexsoft_describe_action',
          ),
        },
        required: ['name'],
      ),
    ),
    (request) async {
      final args = request.arguments!;
      final name = args['name'] as String;
      requireAllowedAction(name, admin: server.isAdmin);
      final params =
          (args['params'] as Map?)?.cast<String, Object?>() ?? const {};
      final result = await client.postJson(
        '/actions/${Uri.encodeComponent(name)}',
        params,
      );
      if (_looksLikeJob(result)) {
        return mcpText(jobToMarkdown(shared.Job.fromJson(result)));
      }
      return mcpText(resultToMarkdown(result));
    },
  );
}
