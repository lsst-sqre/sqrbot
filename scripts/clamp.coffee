# Commands:
#   hubot clamp - Hubot requests to clamp
module.exports = (robot) ->

  robot.respond /clamp/i, (res) ->
    robot.logger.debug "Received #{res.message.text}"
    res.send "Want me to clamp 'im, boss?"
