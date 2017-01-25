# Commands:
#   `@sqrbot clamp` - Do what comes naturally.
module.exports = (robot) ->

  robot.respond /clamp/i, (res) ->
    robot.logger.debug "Received #{res.message.text}"
    res.reply "Want me to clamp 'im, boss?"
