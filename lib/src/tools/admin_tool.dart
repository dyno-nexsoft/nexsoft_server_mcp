import 'package:dart_mcp/server.dart';
import 'package:nexsoft_server_shared/nexsoft_server_shared.dart' as shared;

import '../job_formatter.dart';
import '../markdown.dart';
import '../mcp_response.dart';
import '../nexsoft_client.dart';
import '../server.dart';

String _paramsToMarkdown(List<shared.ActionParam> params) {
  if (params.isEmpty) return '_No parameters._';
  return params.map((p) {
    final req = p.isRequired ? '**required**' : 'optional';
    final choices =
        p.choices.isNotEmpty ? ', choices: ${p.choices.join('/')}' : '';
    final def = p.defaultValue != null ? ', default: ${p.defaultValue}' : '';
    return '- `${p.name}` (${p.type.toWire()}, $req$choices$def) — ${p.description}';
  }).join('\n');
}

bool _looksLikeJob(Map<String, dynamic> data) =>
    data['state'] is String && data['action_name'] is String;

/// Registers the tools that reach the actions Swagger does not document, and so
/// only for an admin key (see [NexsoftMcpServer]): list them, describe one, and
/// call one by name with its params. The tool list any other key sees is exactly
/// what Swagger shows and nothing more.
///
/// Each call is still checked by nexsoft_server against the key's own role.
void registerAdminTools(NexsoftMcpServer server, NexsoftClient client) {
  server.registerTool(
    Tool(
      name: 'nexsoft_list_actions',
      description: 'Every action the server has, with permission and kind '
          '(query/mutation/job): the ones Swagger documents and the hidden '
          "ones. Use nexsoft_describe_action for one action's parameters.",
      inputSchema: Schema.object(),
    ),
    (request) async {
      final json = await client.getJson('/actions');
      final rows = (json['actions'] as List)
          .map((a) => shared.ActionSchema.fromJson(a as Map<String, dynamic>))
          .map(
            (a) =>
                '| `${a.name}` | ${a.kind.name} | ${a.permission.toWire()} | ${a.description} |',
          )
          .join('\n');
      return mcpText(
        '| Action | Kind | Permission | Description |\n'
        '| --- | --- | --- | --- |\n$rows',
      );
    },
  );

  server.registerTool(
    Tool(
      name: 'nexsoft_describe_action',
      description: 'Full parameter schema for one action, by name.',
      inputSchema: Schema.object(
        properties: {
          'name': Schema.string(
              description: 'Action name, as nexsoft_list_actions shows it'),
        },
        required: ['name'],
      ),
    ),
    (request) async {
      final name = request.arguments!['name'] as String;
      final action = shared.ActionSchema.fromJson(
        await client.getJson('/actions/${Uri.encodeComponent(name)}'),
      );
      return mcpText(
        '### ${action.name}\n\n${action.description}\n\n'
        '- **kind**: ${action.kind.name}\n'
        '- **permission**: ${action.permission.toWire()}\n\n'
        '**Params**\n\n${_paramsToMarkdown(action.params)}',
      );
    },
  );

  server.registerTool(
    Tool(
      name: 'nexsoft_invoke_action',
      description:
          'Call any action by name with its params (POST /actions/{name}), '
          'including the ones Swagger does not show. Returns the job for '
          "kind='job' actions, the result otherwise.",
      inputSchema: Schema.object(
        properties: {
          'name': Schema.string(
            description: "Action name, as nexsoft_list_actions shows it",
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
      final params =
          (args['params'] as Map?)?.cast<String, Object?>() ?? const {};
      final result = await client.postJson(
        '/actions/${Uri.encodeComponent(name)}',
        params,
      );
      if (_looksLikeJob(result)) {
        return mcpText(jobToMarkdown(shared.Job.fromJson(result)));
      }
      if (result['lines'] is List) return mcpText(logLinesToMarkdown(result));
      return mcpText(resultToMarkdown(result));
    },
  );
}
