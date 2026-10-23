import 'package:dart_mcp/server.dart';
import 'package:nexsoft_server_shared/nexsoft_server_shared.dart';

import '../mcp_response.dart';
import '../nexsoft_client.dart';
import '../server.dart';

String _hours(WorkHours h) => '${h.start}–${h.end}'
    '${h.lunchStart == null ? '' : ' (lunch ${h.lunchStart}–${h.lunchEnd})'}';

/// The schedule as one readable block: the week, the exceptions and the jobs
/// with when each runs next.
String scheduleToMarkdown(ScheduleInfo info) {
  const days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  final week = [
    for (final rule in info.calendar.weekdays)
      '| ${days[rule.weekday - 1]} | ${rule.working ? 'working' : 'off'} '
          '| ${_hours(rule.hours)} |',
  ];
  final exceptions = info.calendar.exceptions.isEmpty
      ? '_None._'
      : [
          for (final e in info.calendar.exceptions)
            '- `${e.date}` — ${e.working ? 'working day' : 'day off'}'
                '${e.hours == null ? '' : ' ${_hours(e.hours!)}'}'
                '${e.note.isEmpty ? '' : ' · ${e.note}'}',
        ].join('\n');
  final jobs = [
    for (final job in info.jobs)
      '| `${job.config.name}` | ${job.config.kind.name} '
          '| ${job.config.enabled ? 'on' : 'off'} | ${job.rule} '
          '| ${job.nextRun?.toIso8601String() ?? '—'} |',
  ];
  return [
    '**Working week** (server local time)\n\n| Day | | Hours |\n| --- | --- | --- |\n${week.join('\n')}',
    '**Exceptions**\n\n$exceptions',
    '**Jobs**\n\n| Name | Kind | | Rule | Next run |\n| --- | --- | --- | --- | --- |\n${jobs.join('\n')}',
  ].join('\n\n');
}

/// The tools that show the server's configuration: the working calendar and
/// the scheduled jobs, the admin limits, and the AI provider.
///
/// Read only on purpose. Changing any of it is an admin's job, on the
/// dashboard: this server runs with a key that may read and run jobs, nothing
/// more (see `allowed_actions.dart`).
void registerConfigTools(NexsoftMcpServer server, NexsoftClient client) {
  // ---- schedule ---------------------------------------------------------

  server.registerTool(
    Tool(
      name: 'nexsoft_schedule_get',
      description:
          'Show the working calendar (which weekdays are worked and their '
          'hours), the days off and make-up days, and every scheduled job '
          'with its rule and next run (schedule.get).',
      inputSchema: Schema.object(),
    ),
    (request) async => mcpText(scheduleToMarkdown(await client.scheduleGet())),
  );

  // ---- limits -----------------------------------------------------------

  String limitsToMarkdown(AppLimits limits) {
    final json = limits.toJson();
    return [
      '| Limit | Value | Allowed |',
      '| --- | ---: | --- |',
      for (final entry in AppLimits.ranges.entries)
        '| `${entry.key}` | ${json[entry.key]} '
            '| ${entry.value.min}–${entry.value.max} |',
    ].join('\n');
  }

  server.registerTool(
    Tool(
      name: 'nexsoft_limits_get',
      description:
          'Show the limits an admin can change — history retention, build '
          'timeout, daily-report sweep, review and AI settings — with the '
          'range each allows (limits.get).',
      inputSchema: Schema.object(),
    ),
    (request) async =>
        mcpText(limitsToMarkdown((await client.limitsGet()).limits)),
  );

  // ---- AI provider ------------------------------------------------------

  String providerToMarkdown(AiProviderInfo info) =>
      '- **Active provider**: `${info.provider}`\n'
      '- **Available** (have API keys): ${info.available.map((p) => '`$p`').join(', ')}\n'
      '- **Failover to the other provider**: ${info.failover ? 'on' : 'off'}\n'
      '- **Models** (Flash / Pro): '
      'gemini `${info.models.geminiFlash}` / `${info.models.geminiPro}`, '
      'groq `${info.models.groqFlash}` / `${info.models.groqPro}`';

  server.registerTool(
    Tool(
      name: 'nexsoft_ai_provider_get',
      description:
          'Show which AI provider (gemini or groq) serves reviews, translations '
          'and announcements, which have API keys, and whether the other takes '
          'over when the active one is down (admin.aiProvider.get).',
      inputSchema: Schema.object(),
    ),
    (request) async =>
        mcpText(providerToMarkdown(await client.aiProviderGet())),
  );
}
