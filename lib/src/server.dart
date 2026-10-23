import 'dart:async';

import 'package:dart_mcp/server.dart';
import 'package:nexsoft_server_shared/nexsoft_server_shared.dart';

import 'markdown.dart';
import 'nexsoft_client.dart';
import 'tools/action_tool.dart';
import 'tools/admin_tool.dart';
import 'tools/build_tool.dart';
import 'tools/config_tool.dart';
import 'tools/job_tool.dart';
import 'tools/meta_tool.dart';
import 'tools/zentao_tool.dart';

/// Kept in sync with `pubspec.yaml`'s `version:` by hand — this process has
/// no bundled `package.json`-equivalent to read its own version from at
/// runtime.
const mcpServerVersion = '5.5.0';

/// nexsoft_server's MCP server: a thin, discoverable wrapper over its REST API
/// (`docs/rest-api.md` in the nexsoft_server repo). Every tool is a direct
/// mapping to one REST endpoint or action — no business logic lives here.
base class NexsoftMcpServer extends MCPServer with ToolsSupport {
  NexsoftMcpServer(super.channel, {NexsoftClient? client})
      : client = client ?? NexsoftClient(),
        super.fromStreamChannel(
          implementation: Implementation(
            name: 'nexsoft_server MCP Server',
            version: mcpServerVersion,
          ),
        ) {
    registerMetaTools(this, this.client);
    registerJobTools(this, this.client);
    registerBuildTools(this, this.client);
    registerZentaoTools(this, this.client);
    registerConfigTools(this, this.client);
    registerActionTools(this, this.client);
    initialized.then((_) => _offerAdminTools());
  }

  final NexsoftClient client;

  /// Whether the API key is an admin's, which is what adds the tools of
  /// `tools/admin_tool.dart`. False until the server has said so.
  bool get isAdmin => _isAdmin;
  var _isAdmin = false;

  /// Asks the server what the key may do (`system.whoami`) and, for an admin,
  /// registers the deploy and log tools; the client is told the tool list
  /// changed. Any failure leaves the plain read-and-run set, which is the safe
  /// side: a key that cannot be identified gets no extra tool.
  Future<void> _offerAdminTools() async {
    try {
      final me = await client.whoAmI();
      if (!me.isAdmin) return;
      _isAdmin = true;
      registerAdminTools(this, client);
    } catch (_) {
      // Not identified: stay with the tools every key gets.
    }
  }

  /// Every tool runs inside a guard: a failure comes back as an error result
  /// with a short Markdown message rather than escaping as an exception whose
  /// stack trace becomes the tool's output.
  @override
  void registerTool(
    Tool tool,
    FutureOr<CallToolResult> Function(CallToolRequest) impl, {
    bool validateArguments = true,
  }) =>
      super.registerTool(tool, (request) async {
        try {
          return await impl(request);
        } catch (error) {
          return CallToolResult(
            isError: true,
            content: [TextContent(text: errorToMarkdown(error))],
          );
        }
      }, validateArguments: validateArguments);
}
