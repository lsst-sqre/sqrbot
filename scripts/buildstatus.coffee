# Commands:
#   `@sqrbot buildstatus <job>` - Fetch status of CI build job _job_
module.exports = (robot) ->
  rootCas = require('ssl-root-cas').create()
  require('https').globalAgent.options.ca = rootCas
  robot.respond /buildstatus (\S+)/i, (msg) ->
    jerb = msg.match[1]
    headers = make_auth_headers()
    robot.http("https://api.lsst.codes/buildstatus/#{jerb}")
    .headers(headers)
    .get() (err, res, body) ->
      if err
        msg.reply "Error: #{err}"
        return
      try
        content = JSON.parse(body)
        console.log(content)
        hro = content.healthReport
        console.log(hro)
        hr = content.healthReport[0]
        console.log(hr)
        desc = hr.description
        score = hr.score
        color = content.color
        colorstr = ":grey_question:"
        switch color
          when "blue" then colorstr=":large_blue_circle:"
          when "red" then colorstr=":broken_heart:"
          when "yellow" then colorstr=":warning:"
          when "grey" then colorstr=":grey_exclamation:"
          else colorstr=":grey_question:"
        retstr = "#{colorstr} [ Job #{jerb} ] #{desc} (Score = #{score})"
        msg.reply retstr
      catch error
        msg.reply "Could not get status for job #{jerb} -- check the name."
        msg.reply "Error was: #{error}"

make_auth_headers = ->
  user = process.env["HUBOT_GITHUB_USER"]
  password = process.env["HUBOT_GITHUB_TOKEN"]
  auth = new Buffer("#{user}:#{password}").toString('base64')
  ret =
    Accept: "application/json"
    Authorization: "Basic #{auth}"
