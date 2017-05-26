# Commands:
#   `DM-<ticketid>` - Return link to that Jira ticket.
#   `RFC-<ticketid>` - Return link to *that* RFC.
moment = require("moment")

module.exports = (robot) ->
  rootCas = require('ssl-root-cas/latest').create()
  require('https').globalAgent.options.ca = rootCas
  ticketId = null
  robot.hear /(^|\s+)(DM|RFC)-\d+/gi, (msg) ->
    # Link to the associated tickets
    issueResponses(robot, msg)


issueResponses = (robot, msg) ->
  ticketIds = msg.match
  for ticketId in ticketIds
    ticketId = ticketId.toUpperCase()
    urlstr="https://jira.lsstcorp.org/rest/api/latest/issue/#{ticketId}"
    robot.http(urlstr).get() (err, res, body) ->
      if err
        msg.send("(Error talking to Jira: `#{err}`)")
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
