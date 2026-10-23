import 'package:dart_mcp/server.dart';
import 'package:nexsoft_server_shared/nexsoft_server_shared.dart';

import '../job_formatter.dart';
import '../mcp_response.dart';
import '../nexsoft_client.dart';
import '../server.dart';

/// Registers the two read-only server calls Swagger documents: `GET /health` and
/// `GET /status`.
void registerMetaTools(NexsoftMcpServer server, NexsoftClient client) {
  server.registerTool(
    Tool(
      name: 'nexsoft_health',
      description:
          'Liveness probe for the nexsoft_server REST API. No auth required.',
      inputSchema: Schema.object(),
    ),
    (request) async {
      final health = Health.fromJson(await client.getJson('/health'));
      return mcpText(
        '- **ok**: ${health.ok}\n'
        '- **version**: ${health.version}\n'
        '- **app_version**: ${health.appVersion}\n'
        '- **uptime_seconds**: ${health.uptimeSeconds}\n'
        '- **hostname**: ${health.hostname}',
      );
    },
  );

  server.registerTool(
    Tool(
      name: 'nexsoft_status',
      description:
          'Queue state and environment: Dart version, uptime, running and queued jobs.',
      inputSchema: Schema.object(),
    ),
    (request) async {
      final status = SystemStatus.fromJson(await client.getJson('/status'));
      final header = [
        '- **hostname**: ${status.hostname}',
        '- **dartVersion**: ${status.dartVersion}',
        '- **uptime**: ${status.uptime}',
        '- **workingDirectory**: ${status.workingDirectory}',
      ].join('\n');
      final running = jobsToMarkdown(status.running);
      final queued = jobsToMarkdown(status.queued);
      return mcpText(
        '$header\n\n### Running\n\n$running\n\n### Queued\n\n$queued',
      );
    },
  );
}
