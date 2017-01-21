# Commands:
#   hubot newproject list - Describe kinds of projects that can be set up
#   hubot newproject describe <project-type> - show cookiecutter.json for project-type
#

typecache = null
timerid = null
svc = "https://api.lsst.codes/ccutter"

module.exports = (robot) ->
  pollprojects(robot) 
  rootCas = require('ssl-root-cas/latest').create()
  require('https').globalAgent.options.ca = rootCas
  robot.respond /newproject\s+list$/i, (msg) ->
    repstr = "I know about the following project types:\n"
    for type of typecache
      repstr += "  `#{type}`\n"
    msg.send "#{repstr}"
    return
  robot.respond /newproject\s+describe\s+(\S+)$/i, (msg) ->
    ptype = msg.match[1]
    if typecache.ptype
      msg.send "`" + JSON.stringify(typecache.ptype) + "`"
      return
    msg.send "I don't know about project type `#{ptype}`"
    return

repopulate_cache = (robot) ->
  robot.http("#{svc}/").get() (err, res, body) ->
    if err
      return
    try
      content = JSON.parse(body)
      typecache = clone(content)

# https://coffeescript-cookbook.github.io/chapters/classes_and_objects/cloning

clone = (obj) ->
  if not obj? or typeof obj isnt 'object'
    return obj
 
  if obj instanceof Date
    return new Date(obj.getTime())

  if obj instanceof RegExp
    flags = ''
    flags += 'g' if obj.global?
    flags += 'i' if obj.ignoreCase?
    flags += 'm' if obj.multiline?
    flags += 'y' if obj.sticky?
    return new RegExp(obj.source, flags)

  newInstance = new obj.constructor()

  for key of obj
    newInstance[key] = clone obj[key]

  return newInstance

pollprojects = (robot) ->
  if ! timerid?
    secs = 3600 # Check every hour
    interval = secs * 1000
    repopulate_cache(robot)
    timerid = setInterval ->
      repopulate_cache(robot)
    , interval


  
