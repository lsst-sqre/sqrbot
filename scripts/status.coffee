# Commands:
#   hubot status - Fetch status of various LSST services
module.exports = (robot) ->
  robot.respond /status/i, (res) ->
    https = require 'https'
    opts =
      host: 'api.lsst.codes',
      path: '/status/'
    req = https.get opts, (hres) ->
      c = ""
      hres.on 'data', (chk) ->
        c += "#{chk}"
      hres.on 'end', () ->
        content = JSON.parse c
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
        res.send retstr
    req.on 'error', (e) ->
      res.send "Error: {e.message}"
