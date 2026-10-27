import 'package:dart_mcp/server.dart';
import 'package:nexsoft_server_shared/nexsoft_server_shared.dart';

import '../job_formatter.dart';
import '../mcp_response.dart';
import '../nexsoft_client.dart';
import '../server.dart';

// Sourced from the shared enums themselves rather than hand-copied lists —
// the same class of drift hard constraint #4 warns about: `_buildPlatforms`
// previously spelled `mobile`/`desktop` next to `android`/`ios`/`macos`/
// `windows`, which quietly went stale the moment those two were renamed.
final _buildPlatforms = [for (final p in PlatformBuild.values) p.toWire()];
final _buildEnvironments = [for (final e in EnvironmentBuild.values) e.name];
final _interactionTypes = [for (final t in PostInteractionType.values) t.name];

/// `runs_on`, for the jobs a build machine may run. A plain string: the labels
/// are the server's (its host names and its configuration), so it checks them
/// and names the known ones when one is wrong.
final _runsOn = Schema.string(
  description: 'Machine to run on, by label: local, a build machine host or '
      'short name, or a label of its own (default: any machine)',
);

/// `timeout_minutes` and `retries`, for the same jobs as [_runsOn].
final _jobOptions = {
  'timeout_minutes': Schema.int(
    minimum: 1,
    description: 'Stop the job as failed after this many minutes (default and '
        'maximum: the server\'s build_timeout_minutes limit)',
  ),
  'retries': Schema.int(
    minimum: 0,
    maximum: 2,
    description: 'Run a failed job again, up to 2 times (never after a cancel, '
        'a timeout, a lost connection or a Firebase upload)',
  ),
};

/// The calls Swagger gives a path of their own: `POST /builds`, `/reposts` and
/// `/interactions`. Every other action (gen, replace, clean, ...) is reached only
/// by an admin key, through `nexsoft_invoke_action`.
void registerBuildTools(NexsoftMcpServer server, NexsoftClient client) {
  server.registerTool(
    Tool(
      name: 'nexsoft_ci_build',
      description:
          'Trigger a CI build job (POST /builds, alias for the ci.build '
          'action). Returns immediately with a queued/running job.',
      inputSchema: Schema.object(
        properties: {
          'tbchat': Schema.string(description: 'Branch repo tbchat'),
          'database': Schema.string(description: 'Branch repo database'),
          'im': Schema.string(description: 'Branch module Instant Message'),
          'wallet': Schema.string(description: 'Branch module Wallet'),
          'cloud_storage': Schema.string(
            description: 'Branch module Cloud Storage',
          ),
          'socialfi': Schema.string(description: 'Branch module Socialfi'),
          'platform': UntitledSingleSelectEnumSchema(
            values: _buildPlatforms,
            description: 'Platform to build (default: android,ios)',
          ),
          'environment': UntitledSingleSelectEnumSchema(
            values: _buildEnvironments,
            description: 'Build environment (default: dev)',
          ),
          'release_notes': Schema.string(description: 'Release notes'),
          'build_name': Schema.string(
            description: "Build name, e.g. 1.4.2 (default: today's date)",
          ),
          'build_number': Schema.int(
            minimum: 1,
            description: 'Build number, e.g. 42 (default: time of day)',
          ),
          'skip_firebase_distribution': Schema.bool(
            description: 'Skip uploading the build to Firebase App '
                'Distribution (default: false)',
          ),
          'flutter_args': Schema.list(
            items: Schema.string(),
            description: 'Extra flutter build flags, one word each, e.g. '
                '--dart-define=ENABLE_HTTP3=false (a define wins over the '
                '.env file)',
          ),
          'runs_on': _runsOn,
          ..._jobOptions,
        },
        required: ['tbchat', 'database'],
      ),
    ),
    (request) async {
      final job = Job.fromJson(
        await client.postJson('/builds', request.arguments ?? const {}),
      );
      return mcpText('### Build queued\n\n${jobToMarkdown(job)}');
    },
  );

  server.registerTool(
    Tool(
      name: 'nexsoft_ci_interaction',
      description:
          'Like, share, view or comment on one TBChat SocialFi post as the accounts kept for an environment (the ones '
          'the reposts created), so a post shows the activity without anyone doing it by hand (POST /interactions, '
          'alias for ci.interaction). Each goes to the server the way the app sends it; a post an account likes '
          'already is left alone (a second like would take the first back). The post is its share link, whose host says the environment. '
          'Returns a queued/running job.',
      inputSchema: Schema.object(
        properties: {
          'type': UntitledSingleSelectEnumSchema(
            values: _interactionTypes,
            description: 'like, share, view or comment',
          ),
          'post': Schema.string(
            description:
                "Share link of a SocialFi post or comment (from its Share menu). Its host says which environment's "
                'accounts act, see ci.interactionHosts.get',
          ),
          'limit': Schema.int(
            description: 'How many accounts do it, picked at random, 1-1000 '
                '(default: all of them)',
          ),
        },
        required: ['type', 'post'],
      ),
    ),
    (request) async {
      final job = Job.fromJson(
        await client.postJson('/interactions', request.arguments ?? const {}),
      );
      return mcpText('### Interaction queued\n\n${jobToMarkdown(job)}');
    },
  );

  server.registerTool(
    Tool(
      name: 'nexsoft_ci_reposts',
      description:
          'Repost TikTok, YouTube, Facebook, Instagram or Threads videos to TBChat SocialFi (POST /reposts, alias for '
          'ci.reposts). Returns a queued/running job.',
      inputSchema: Schema.object(
        properties: {
          'url': Schema.string(
              description:
                  'TikTok, YouTube, Facebook, Instagram or Threads video or profile link; '
                  'several links: one per line, or separated by spaces (up to 10, posted one after the other)'),
          'environment': UntitledSingleSelectEnumSchema(
            values: _buildEnvironments,
            description: 'Environment (default: dev)',
          ),
          'limit': Schema.int(
            description: 'Most recent videos to take from a profile, 1-20 '
                '(default 3)',
          ),
        },
        required: ['url'],
      ),
    ),
    (request) async {
      final job = Job.fromJson(
        await client.postJson('/reposts', request.arguments ?? const {}),
      );
      return mcpText('### Reposts queued\n\n${jobToMarkdown(job)}');
    },
  );
}
