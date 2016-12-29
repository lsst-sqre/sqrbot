# Commands:
#   hubot metricdeviation <metric> <threshold> - Report whether metric <metric> (legal values are AM1, AM2, PA1) has changed  more than <threshold>% since last run
#   hubot metricdeviation:monitor <interval> <threshold> - Set up a poll for metrics (AM1, AM2, PA1) every <interval> seconds to check for changes of more than <threshold>% since last run
#   hubot metricdeviation:unmonitor - Cancel monitoring poll

timerid = null # static across messages


module.exports = (robot) ->
  rootCas = require('ssl-root-cas/latest').create();
  require('https').globalAgent.options.ca = rootCas;
  robot.respond /metricdeviation (\S+)\s+(\S+)$/i, (msg) ->
    metric = msg.match[1]
    threshold = msg.match[2]
    getmetric(robot,msg,metric,threshold,true)
  robot.respond /metricdeviation (\S+)$/i, (msg) ->
    metric = msg.match[1]
    getmetric(robot,msg,metric,"0",true)
  robot.respond /metricdeviation:monitor (\S+)\s+(\S+)$/i, (msg) ->
    if not timerid
      intervalstr = msg.match[1]
      interval=parseInt(intervalstr,10) * 1000
      if isNaN(interval)
        arghstr = "Could not understand putative number #{intervalstr}. "
        arghstr += "Using default of 8 hours instead."
        msg.send "#{arghstr}"
        interval = 1000 * 60 * 60 * 8
      threshold = msg.match[2]
      loopmetrics(robot,msg,threshold)
      timerid = setInterval ->
        loopmetrics(robot,msg,threshold)
      , interval
      msg.send "Metric deviation monitoring enabled."
    else
      msg.send "Metric deviation monitoring already enabled."
  robot.respond /metricdeviation:unmonitor/i, (msg) ->
    if timerid
      clearInterval(timerid)
      msg.send "Metric deviation monitoring disabled."
      timerid = null
    else
      msg.send "Metric deviation monitoring already disabled."


getmetric = (robot,msg,metric,threshold,interactive) ->
  headers = make_auth_headers()
  robot.http("https://api.lsst.codes/metricdeviation/#{metric}/#{threshold}")
  .headers(headers)
  .get() (err, res, body) ->
    if err
      msg.send "Error: `#{err}`"
      return
    try
      content = JSON.parse(body)
      if content.changed
        current = content.current
        previous = content.previous
        delta_pct = content.delta_pct
        retstr = "Metric `#{metric}` changed by more than `#{threshold}%`"
        retstr += " in the last run."
        retstr += "\nCurrent value: `#{current}` / "
        retstr += "Previous value: `#{previous}`."
        retstr += "\nChange was `#{delta_pct}%`."
        if content.changecount > 0
          count = content.changecount
          changelist = content.changed_packages.toString()
          retstr += "\n`#{count}` packages changed: `#{changelist}`."
        console.log(retstr)
        msg.send "#{retstr}"
      else
        if interactive
          retstr = "Metric `#{metric}` did not change more than `#{threshold}%`"
          retstr += " in the last run."
          msg.send "#{retstr}"
    catch error
      msg.send "Could not get metric `#{metric}` for `#{threshold}%` change."
      msg.send "Error was: `#{error}`"
      msg.send "Body of response was: `#{body}`"


loopmetrics = (robot,msg,threshold) ->
  metrics = [ "AM1", "AM2", "PA1" ]
  for metric in metrics
    getmetric(robot,msg,metric,threshold,false)


make_auth_headers = ->
  user = process.env["HUBOT_GITHUB_USER"]
  password = process.env["HUBOT_GITHUB_PASSWORD"]
  auth = new Buffer("#{user}:#{password}").toString('base64')
  ret =
    Accept: "application/json"
    Authorization: "Basic #{auth}"
