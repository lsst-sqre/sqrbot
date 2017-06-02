# Commands:
#   `DM-<ticketid>` - Return link to that Jira ticket.
#   `RFC-<ticketid>` - Return link to *that* RFC.
moment = require("moment")
{TextMessage} = require("hubot/src/message")

BOT_NAMES = ["jirabot"]

module.exports = (robot) ->
  rootCas = require('ssl-root-cas/latest').create()
  require('https').globalAgent.options.ca = rootCas
  ticketId = null
  robot.listen(
    # Matcher
    (message) ->
      if message instanceof TextMessage
        match = message.match(/\b(DM|RFC|ITRFC|IHS|PUB)-\d+/gi)
        if match and message.user.name not in BOT_NAMES
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
    if last and now.isBefore last.add(1, 'minute')
      return
    urlstr="https://jira.lsstcorp.org/rest/api/latest/issue/#{ticketId}"
    robot.http(urlstr).get() (err, res, body) ->
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
