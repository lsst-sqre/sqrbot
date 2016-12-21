# Commands:
#   hubot status - Fetch status of various LSST services
# Local variables:
# coffee-tab-width: 4
# End
module.exports = (robot) ->
  require('ssl-root-cas').inject()
  rootCas = require('ssl-root-cas/latest').create();
  require('https').globalAgent.options.ca = rootCas;
  robot.respond /newstatus/i, (msg) ->
    robot.http("https://api.lsst.codes/status/").get() (err, res, body) ->
      if err
        msg.send "Error: #{err}"
        return
      content = JSON.parse(body)
      retstr = "*HOSTS*\n"
      for k, v of content["hosts"]
        if v is "UP"
          retstr += ":white_check_mark:"
        else if v is "DOWN"
          retstr += ":red_circle:"
        else
          retstr += ":question:"
        retstr += " `" + k + "`" + "\n"
      retstr += "\n*SERVICES*\n"
      for k, v of content["services"]
        for k2, v2 of v
          if v2 is "OK"
            retstr += ":white_check_mark:"
          else if v2 is "WARNING"
            retstr += ":large_orange_diamond:"
          else if v2 is "CRITICAL"  
            retstr += ":red_circle:"
          else
            retstr += ":question:"
          retstr += " `" + k + "/" + k2 + "`" + "\n"
      msg.send retstr
