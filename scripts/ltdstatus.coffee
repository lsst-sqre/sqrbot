# coffeelint: disable=max_line_length
# Commands:
#   `@sqrbot ltdstatus` - Report whether all published LSST The Docs product endpoints are available
#   `@sqrbot ltdstatus verbose` - Report whether all published LSST The Docs product endpoints are available, verbosely
#   `@sqrbot ltdstatus <product>` - Report whether published LSST The Docs product endpoints for _product_ are available
#   `@sqrbot ltdstatus <product> verbose` - Report whether published LSST The Docs product endpoints for _product_ are available, verbosely
#   `@sqrbot ltdstatus:monitor <interval>` - Set up a poll for published LSST The Docs product endpoints to run every _interval_ seconds
#   `@sqrbot ltdstatus:unmonitor` - Cancel monitoring poll for LSST The Docs product endpoints

# coffeelint: enable=max_line_length
timerid = null # static across messages


module.exports = (robot) ->
  rootCas = require('ssl-root-cas/latest').create()
  require('https').globalAgent.options.ca = rootCas
  robot.respond /ltdstatus$/i, (msg) ->
    getltdstatus(robot,msg,null,false,true)
    return
  robot.respond /ltdstatus\s+verbose$/i, (msg) ->
    getltdstatus(robot,msg,null,true,true)
    return
  robot.respond /ltdstatus (\S+)$/i, (msg) ->
    product=msg.match[1]
    if "#{product}" is "verbose"
      return # Handled above
    getltdstatus(robot,msg,product,false,true)
    return
  robot.respond /ltdstatus (\S+)\s+verbose$/i, (msg) ->
    product=msg.match[1]
    getltdstatus(robot,msg,product,true,true)
    return
  robot.respond /ltdstatus:monitor (\S+)$/i, (msg) ->
    if not timerid
      intervalstr = msg.match[1]
      secs=parseInt(intervalstr,10)
      if isNaN(secs)
        arghstr = "Could not understand putative number #{intervalstr}. "
        arghstr += "Using default of 8 hours instead."
        msg.reply "#{arghstr}"
        interval = 1000 * 60 * 60 * 8
      interval = secs * 1000
      loopproducts(robot,msg)
      timerid = setInterval ->
        loopproducts(robot,msg)
      , interval
      msg.reply "Product endpoint monitoring enabled: poll #{secs} s."
    else
      msg.reply "Product endpoint monitoring already enabled."
    return
  robot.respond /ltdstatus:unmonitor/i, (msg) ->
    if timerid
      clearInterval(timerid)
      msg.reply "Product endpoint monitoring disabled."
      timerid = null
    else
      msg.reply "Product endpoint monitoring already disabled."
    return


getltdstatus = (robot,msg,product,verbose,interactive) ->
  urlstr="https://api.lsst.codes/ltdstatus/"
  if product
    urlstr += "#{product}"
  console.log("Getting URL #{urlstr}")
  robot.http(urlstr).get() (err, res, body) ->
    if err
      msg.reply "Error: `#{err}`"
      return
    sc = res.statusCode
    if sc > 199 and sc < 300 and not verbose
      if not interactive
        return
      mstr = " endpoints: :+1:"
      if product
        mstr = "Product #{product}" + mstr
      else
        mstr = "All" + mstr
      msg.reply mstr
      return
    mstr = ""
    try
      content = JSON.parse(body)
      for product, prodobj of content
        masterstr = "`#{product}`: "
        produrl = prodobj.url
        if not produrl
          masterstr += "`[MASTER NEVER BUILT]`"
        else
          masterstr += produrl
        edstr = ""
        editions = prodobj.editions
        for vers, verobj of editions
          sc = verobj.status_code
          if verbose or sc < 200 or sc > 299
            url = verobj.url
            urltype = verobj.url_type
            if "#{urltype}" is "product"
              thingstr = ":no_entry:`[ PRODUCT #{product} DOES NOT EXIST ]`\n"
            else if "#{urltype}" is "product_edition_published_url"
              thingstr = ":book:"
            else
              thingstr = ":warning:"
            thisedstr = " `#{vers}`: #{url}"
            if sc < 200 or sc > 299
              aww = ":broken_heart: (`#{sc}`)"
              edstr += "#{thingstr}#{aww}"
              if "#{url}" is "#{produrl}" or "#{url}" is "#{produrl}/"
                masterstr += " #{aww}"
            else
              yay = ":white_check_mark:"
              edstr += "#{thingstr}#{yay}"
              if "#{url}" is "#{produrl}" or "#{url}" is "#{produrl}/"
                masterstr += " " + yay
            edstr += " #{thisedstr}\n"
        mstr += "#{masterstr}\n#{edstr}"
      console.log("Response:\n@@@@\n#{mstr}\n@@@@")
      msg.reply "#{mstr}"
    catch error
      msg.reply "Could not get product status."
      msg.reply "Error was: `#{error}`"
      msg.reply "Body of response was:\n```#{body}```"


loopproducts = (robot,msg) ->
  getltdstatus(robot,msg,null,false,false)
