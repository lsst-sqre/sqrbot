# Commands:
#   `DM-<ticketid>` - Return link to that Jira ticket.
#   `RFC-<ticketid>` - Return link to *that* RFC.
module.exports = (robot) ->
  rootCas = require('ssl-root-cas/latest').create()
  require('https').globalAgent.options.ca = rootCas
  ticketId = null
  robot.hear /(^|\s+)((DM-|RFC-)([\d]+))/i, (msg) ->
    # Link to the associated ticket
    ticketId = msg.match[2]
    updatedMsg = \
      "<https://jira.lsstcorp.org/browse/#{ticketId}|#{ticketId}>"
    # Editing in current slack would require making sqrbot an app and be
    # a lot more hassle, so we're not doing it yet.
    msg.send(updatedMsg)
