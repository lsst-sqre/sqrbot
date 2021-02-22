# coffeelint: disable=max_line_length
# Commands:
#   `@sqrbot project list` - Describe kinds of projects that can be set up
#   `@sqrbot project describe <project-type>` - show cookiecutter.json for project-type
#   `@sqrbot project aliases` - Show friendlier names for project types
#   `@sqrbot project create [ technote | lsst-technote-bootstrap ] title={{<title>}} description={{<description>}} series={{<series>}} [ field1={{<value>}}... ]` (see `@sqrbot project describe technote` for other fields) - Create a new technote
#   `@sqrbot project create [ microservice | uservice-bootstrap ] svc_name={{<service name>}} description={{<description>}} [ field1={{<value>}}... ]` (see `@sqrbot project describe microservice` for other fields) - Create a new microservice

# coffeelint: enable=max_line_length

module.exports = (robot) ->

  svc = "https://api.lsst.codes/ccutter"
  typecache = null
  timerid = null
  # This next thing is gross.  We should fix it on the backend.
  typealias = {
    "lsst-technote-bootstrap": [ "technote" ],
    "uservice-bootstrap": [ "microservice", "uservice" ]
  }

  repopulate_cache = (robot) ->
    robot.http("#{svc}/").get() (err, res, body) ->
      if err
        return
      try
        content = JSON.parse(body)
        typecache = clone(content)
  

  if ! timerid?
    secs = 3600 # Check every hour
    interval = secs * 1000
    repopulate_cache(robot)
    timerid = setInterval ->
      repopulate_cache(robot)
    , interval
  
  rootCas = require('ssl-root-cas').create()
  require('https').globalAgent.options.ca = rootCas
  robot.respond /project\s+list$/i, (msg) ->
    repstr = "I know about the following project types:\n"
    for type of typecache
      repstr += "  `#{type}`"
      if type of typealias
        repstr += ": `#{typealias[type]}`"
      repstr += "\n"
    msg.reply "#{repstr}"
    return
  robot.respond /project\s+describe\s+(\S+)$/i, (msg) ->
    ptype = msg.match[1]
    ntype = resolvetype(ptype)
    if ntype is null
      msg.reply "I don't know about project type `#{ptype}`"
      return
    msg.reply "```" + JSON.stringify((typecache[ntype]),null,2) + "```"
    return
  robot.respond /project\s+aliases$/i, (msg) ->
    repstr = "You can use the following aliases:\n"
    for type of typealias
      repstr += "  `#{type} : #{typealias[type]}`\n"
    msg.reply "#{repstr}"
    return
  robot.respond /project\s+create\s+(\S+)$/i, (msg) ->
    ptype = msg.match[1]
    if resolvetype(ptype) is null
      msg.reply "Unknown project type '#{ptype}'."
      return
    msg.reply "Create '#{ptype}' requires arguments."
    return
  robot.respond /project\s+create\s+(\S+)\s+(.*)$/i, (msg) ->
    ptype = msg.match[1]
    pargs = msg.match[2]
    ntype = resolvetype(ptype)
    if ntype is null
      msg.reply "Unknown project type '#{ptype}'."
      return
    dispatch(robot, msg, ntype,pargs)
    return

  resolvetype = (ptype) ->
    if ptype of typecache
      return ptype
    for cname of typealias
      if ptype in typealias[cname]
        return cname
    return null

  dispatch = (robot, msg, ntype, pargs) ->
    argdict = parse_args(pargs)
    if not argdict?
      msg.reply "I couldn't parse `#{pargs}` into something sensible."
      return
    # Add things we know from the message
    argdict.hubot_name = msg.message.user.profile.real_name
    argdict.hubot_email = msg.message.user.profile.email
    template = typecache[ntype]
    svc_obj = create_request_obj(argdict, template, ntype)
    if not svc_obj.ok
      msg.reply "Cannot create '#{ntype}': #{svc_obj.reason}."
      return
    # Now we've got the thing we're going to send.
    url = "#{svc}/#{ntype}/"
    headers = make_headers()
    data = JSON.stringify(svc_obj.data,null,2)
    robot.http(url).headers(headers).post(data) (err, res, body) ->
      if err
        msg.reply "API request to #{url} got error: #{err}"
        return
      received = null
      sc = res.statusCode
      sr = res.statusMessage
      if sc < 200 or sc > 299
        msg.reply "API request to #{url} failed: #{sc} #{sr}:\n```#{body}```"
        return
      try
        received = JSON.parse(body)
      catch
        msg.reply "Failed to JSON-decode message: ```#{body}```"
        return
      if "message" not of received
        msg.reply "Did not receive `message` in: ```" + \
          JSON.stringify(received, null, 2) + "```"
        return
      msg.reply received.message
    return

  create_request_obj = (argdict, template, ntype) ->
    r = { "ok": false }
    switch ntype
      when "lsst-technote-bootstrap"
        r = replace_technote_fields(argdict,template)
      when "uservice-bootstrap"
        r = replace_microservice_fields(argdict,template)
      else
        r["reason"] = "Unknown project type '#{ntype}'" # Shouldn't get here.
    return r

  # The replace_*_fields are the functions you need to extend as you add
  #  more project types.  They first should get the argdict into canonical
  #  form, and then replace template fields with either the argdict fields
  #  or with dummy fields to be replaced on the server end (e.g. "year").
  #
  # Then make sure you have all the fields you need for the type.
  #
  # Return an object with an "ok" field which is true or false
  #  If it's true, the "data" field is an object to pass to the API service.
  #  If it's false, the "reason" field is a string explaining what went
  #   wrong.

  replace_technote_fields = (argdict, template) ->
    r = { "ok": false }
    # Substitute canonical field names
    if argdict.author? and not argdict.first_author?
      argdict.first_author = argdict.author
      delete argdict.author
    if not argdict.first_author?
      argdict.first_author = argdict.hubot_name
    if argdict.series?
      argdict.series = argdict.series.toUpperCase()
    delete argdict.hubot_name
    # Not used by cookiecutter, but used by git to set author info.
    argdict.github_email = argdict.hubot_email
    delete argdict.hubot_email
    # Copy template to returned data
    rdata = {}
    for fld of template
      rdata[fld] = template[fld]
    # Make sure we delete the fields we really need an answer to
    delete rdata.first_author
    delete rdata.title
    delete rdata.description
    delete rdata.series
    # Substitute argdict data
    for fld of argdict
      rdata[fld] = argdict[fld]
    # Zap server side fields
      rdata.github_org = "replace"
    for i in [ "first_author", "title", "description", "series" ]
      if not rdata[i]?
        if "reason" not of r
          r.reason = ""
        if r.reason != ""
          r["reason"] += "; "
        r["reason"] += "#{i} field is required"
    if r.reason?
      return r
    r.data = rdata
    r.ok = true
    return r

  replace_microservice_fields = (argdict, template) ->
    r = { "ok": false }
    # Substitute canonical field names
    if argdict.author? and not argdict.author_name?
      argdict.author_name = argdict.author
      delete argdict.author
    if not argdict.author_name?
      argdict.author_name = argdict.hubot_name
    if not argdict.email?
      argdict.email = argdict.hubot_email
    delete argdict.hubot_name
    delete argdict.hubot_email
    # Copy template to returned data
    rdata = {}
    for fld of template
      rdata[fld] = template[fld]
    # Make sure we delete the fields we really need an answer to
    delete rdata.author_name
    delete rdata.email
    delete rdata.description
    delete rdata.svc_name
    delete rdata.auth_type
    # Substitute argdict data
    for fld of argdict
      rdata[fld] = argdict[fld]
    if not rdata.auth_type? # Pick "none" as default.
      rdata.auth_type = "none"
    for i in [ "author_name", "email", "description", "svc_name" ]
      if not rdata[i]?
        if "reason" not of r
          r.reason = ""
        if r.reason != ""
          r["reason"] += "; "
        r["reason"] += "#{i} field is required"
    if r.reason?
      return r
    r.data = rdata
    r.ok = true
    return r

  parse_args = (pargs) ->
    r = {}
    parsepattern = ///
    \s*          # optional leading whitespace
    (\S+)        # capture token name
    \s*          # optional whitespace
    =            # equals sign
    \s*          # optional whitespace
    \{\{         # double open curly bracket
    (.*?)        # capture value; zero or more of anything, non-greedy
    \}\}         # double close curly bracket
    (.*)         # rest of input
    ///
    try
      while pargs != ""
        [ token, value, rest ] = pargs.match(parsepattern)[1..3]
        r[token] = value
        pargs = rest
    catch
      r = null
    return r

  make_headers = ->
    # magic environment variables.
    user = process.env["HUBOT_GITHUB_USER"]
    password = process.env["HUBOT_GITHUB_TOKEN"]
    auth = new Buffer("#{user}:#{password}").toString('base64')
    ret =
      Accept: "application/json"
      "Content-Type": "application/json"
      Authorization: "Basic #{auth}"



    
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



  
