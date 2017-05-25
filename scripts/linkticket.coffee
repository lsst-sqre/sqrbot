# Commands:
#   `DM-<ticketid>` - Return link to that Jira ticket.
#   `RFC-<ticketid>` - Return link to *that* RFC.
module.exports = (robot) ->
  rootCas = require('ssl-root-cas/latest').create()
  require('https').globalAgent.options.ca = rootCas
  ticketId = null
  robot.hear /(DM|RFC)-\d+/g, (context) ->
    # Link to the associated tickets
      summary = getJiraSummary(robot, context.match[1..])
      msg.send(summary)

getJiraSummary = (robot,ticketIds) ->
  attachments = []
  for ticketId in ticketIds
    urlstr="https://jira.lsstcorp.org/rest/api/latest/issue/#{ticketId}"
    robot.http(urlstr).get() (err, res, body) ->
      if err
        return "(Error talking to Jira: `#{err}`)"
      try
        issue = JSON.parse(body)
        attachments.push(getAttachment(issue))
      catch error
        return "Error parsing JSON: `#{error}`"
  attachments: attachments

getAttachment = (issue) ->
  response = fallback: ''
  response.fallback = issue.key + ": " + issue.fields.summary
  response.color = "#88bbdd"
  response.mrkdwn_in = [ 'text' ]
  # Parse text as markdown
  issue_md = "<https://jira.lsstcorp.org/browse/#{issue.key}|#{issue.key}>"
  status_md = "`#{issue.fields.status.name}`"
  response.text = issue_md + ": " + status_md + " " + issue.fields.summary
  response.footer = issue.fields.assignee.displayName
  response.footer_icon = issue.fields.status.iconUrl
  response.ts = moment(issue.fields.created)
  response
