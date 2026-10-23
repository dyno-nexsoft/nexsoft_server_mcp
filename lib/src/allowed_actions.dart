/// The actions this MCP server will call for a key that is not an admin's:
/// reading, and running, cancelling and promoting jobs.
///
/// An AI client can be talked into anything a tool lets it do, so such a key
/// gets no tool that administers nexsoft_server (API keys, Restart, Hot Reload,
/// logs, limits, the schedule, the AI provider, cron) or writes anywhere else
/// (Zentao reports, GitLab reviews, deleting history). This list is what keeps
/// `nexsoft_invoke_action`, which takes any action name, and
/// `nexsoft_retry_job`, which re-runs whatever a job ran, from reaching them
/// anyway.
///
/// It is not the security boundary on its own: the key is. nexsoft_server
/// refuses every admin action for a key whose role is `user` (`read` + `invoke`,
/// never `admin`), whatever is sent. `ci.clean` needs `invoke_dangerous` and is
/// left out for the same reason.
///
/// An admin key is the server's owner working through their own AI client, on
/// a machine that holds the key anyway: it may call every action
/// ([mayCall]), and the server's own permission checks still apply.
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

/// Whether this MCP server will call [name]: any action for an [admin] key,
/// only [allowedActions] otherwise.
bool mayCall(String name, {required bool admin}) =>
    admin || allowedActions.contains(name);

/// Refuses [name] unless [mayCall] allows it, before anything is sent.
void requireAllowedAction(String name, {required bool admin}) {
  if (!mayCall(name, admin: admin)) {
    throw ArgumentError.value(
      name,
      'name',
      'is not available through this MCP server for this key, which may only '
          'read and run jobs. Use the dashboard for it',
    );
  }
}
