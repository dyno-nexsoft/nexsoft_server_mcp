import 'package:dart_mcp/server.dart';
import 'package:nexsoft_server_shared/nexsoft_server_shared.dart';

import '../markdown.dart';
import '../mcp_response.dart';
import '../nexsoft_client.dart';
import '../server.dart';

/// Registers the one Zentao tool left: reading a daily report task, which
/// needs the caller's Discord account to be linked to a Zentao account. Writing
/// to Zentao (start, finish, close, edit a report) is not offered: this server
/// only reads and runs jobs (see `allowed_actions.dart`).
void registerZentaoTools(NexsoftMcpServer server, NexsoftClient client) {
  server.registerTool(
    Tool(
      name: 'nexsoft_zentao_report_get',
      description:
          'View full detail of a daily report task (zentao.report.get).',
      inputSchema: Schema.object(
        properties: {'task_id': Schema.int(description: 'Zentao task id')},
        required: ['task_id'],
      ),
    ),
    (request) async {
      final task = await client
          .zentaoReportGet(ZentaoTaskParams(taskId: _taskId(request)));
      return mcpText(resultToMarkdown(task.toJson()));
    },
  );
}

int _taskId(CallToolRequest request) =>
    (request.arguments!['task_id'] as num).toInt();
