/// The actions this MCP server will call for every key: reading, and running,
/// cancelling and promoting jobs.
///
/// An AI client can be talked into anything a tool lets it do, so a key that is
/// not an admin gets no tool that administers nexsoft_server (API keys, Restart,
/// Hot Reload, logs, limits, the schedule, the AI provider, cron) or writes
/// anywhere else (Zentao reports, GitLab reviews, deleting history). This list
/// is what keeps `nexsoft_invoke_action`, which takes any action name, from
/// reaching them anyway.
///
/// It is not the security boundary on its own: the key is. nexsoft_server
/// refuses every admin action for a key whose role is `user` (`read` + `invoke`,
/// never `admin`), whatever is sent. `ci.clean` needs `invoke_dangerous` and is
/// left out for the same reason.
const allowedActions = {
  // Jobs.
  'ci.build',
  'ci.gen',
  'ci.interaction',
  'ci.replace',
  'ci.reposts',
  'ci.upload',
  'ci.job.cancel',
  'ci.job.promote',

  // Reads.
  'admin.aiProvider.get',
  'ci.interactionHosts.get',
  'gitlab.review.history',
  'gitlab.translateArb.history',
  'limits.get',
  'notifications.list',
  'p2p.files.list',
  'schedule.get',
  'system.status',
  'zentao.report.get',
  'zentao.status',
};

/// What an admin key may also call, matching the tools of `tools/admin_tool.dart`:
/// deploying and reading the server's log. Nothing else that administers the server.
const adminActions = {'admin.logs.tail', 'system.hotReload', 'system.restart'};

/// Refuses [name] unless it is in [allowedActions], or in [adminActions] when
/// the key is an [admin], before anything is sent.
void requireAllowedAction(String name, {bool admin = false}) {
  if (!allowedActions.contains(name) &&
      !(admin && adminActions.contains(name))) {
    throw ArgumentError.value(
      name,
      'name',
      'is not available through this MCP server for this key, which may only '
          'read and run jobs. Use the dashboard for it',
    );
  }
}
