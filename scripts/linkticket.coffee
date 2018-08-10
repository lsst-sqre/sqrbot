# Commands:
#   `DM-<ticketid>` - Return link to that Jira ticket.
#   `RFC-<ticketid>` - Return link to *that* RFC.
#   etc. for other specified ticket types.
moment = require("moment")
{TextMessage} = require("hubot/src/message")

BOT_NAMES = ["jirabot"]
TICKET_PREFIXES = "DM|RFC|ITRFC|IHS|PUB|LIT|TSEIA"
user = process.env.LSST_JIRA_USER
pwd = process.env.LSST_JIRA_PWD

module.exports = (robot) ->
  rootCas = require('ssl-root-cas/latest').create()
  require('https').globalAgent.options.ca = rootCas
  ticketId = null
  robot.listen(
    # Matcher
    (message) ->
      if message instanceof TextMessage and message.user.name not in BOT_NAMES
        txt = message.text
        # Remove code blocks (approximately)
        txt = txt.replace(/```.*?```/g, "")
        # Remove inline code
        txt = txt.replace(/`.*?`/g, "")
        # Protect explicit Jira URLs by making them non-URLs
        txt = txt.replace(/https:\/\/jira\.lsstcorp\.org\/browse\//g, "")
        # Protect "tickets/DM-" (only) when not part of a URL or path
        txt = txt.replace(/tickets\/DM-/g, "DM-")
        # Remove URLs and pathnames (approximately)
        txt = txt.replace(///
          \/(#{TICKET_PREFIXES})
          ///gi, "")
        # Match any ticket identifiers that are left
        match = txt.match(///
          \b(#{TICKET_PREFIXES})-\d+
          ///gi)
        if match
          match
        else
          false
      else
        false
    # Callback
    (response) ->
      # Link to the associated tickets
      issueResponses(robot, response)
  )


issueResponses = (robot, msg) ->
  ticketIds = Array.from(new Set(msg.match))
  for ticketId in ticketIds
    ticketId = ticketId.toUpperCase()
    last = robot.brain.get(ticketId)
    now = moment()
    robot.brain.set(ticketId, now)
    if last and now.isBefore last.add(5, 'minute')
      return
    urlstr="https://jira.lsstcorp.org/rest/api/latest/issue/#{ticketId}"
    robot.http(urlstr,{ecdhCurve: 'auto'}).auth(user, pwd).get() (err, res, body) ->
      if (not res)
        msg.send("Null response from GET #{urlstr}")
        msg.send("Error: #{err}")
        return
      if res.statusCode in [401, 403]
        msg.send("Protected: <https://jira.lsstcorp.org/browse/#{ticketId}|#{ticketId}>")
        return
      if res.statusCode == 404
        # Do Nothing
        # If Something is wrong with Jira, this might
        return
      if err
        msg.send("(Error Retrieving ticket Jira: `#{err}`)")
        return
      try
        issue = JSON.parse(body)
        attachment = getAttachment(issue)
        msg.send({attachments: [attachment]})
      catch error
        msg.send("Error parsing JSON for #{ticketId}: `#{error}`")

getAttachment = (issue) ->
  response = fallback: ''
  response.fallback = issue.key + ": " + issue.fields.summary
  response.color = "#88bbdd"
  response.mrkdwn_in = [ 'text' ]
  # Parse text as markdown
  issue_md = "<https://jira.lsstcorp.org/browse/#{issue.key}|#{issue.key}>"
  status_md = "`#{issue.fields.status.name}`"
  response.text = issue_md + ": " + status_md + " " + issue.fields.summary
  response.footer = 'Unassigned'
  if issue.fields.assignee
    response.footer = issue.fields.assignee.displayName
  if "priority" in issue.fields
    response.footer_icon = issue.fields.priority.iconUrl
  response.ts = moment(issue.fields.created).format("X")
  return response
