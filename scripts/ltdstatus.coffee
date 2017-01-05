# Commands:
#   hubot ltdstatus - Report whether all published product endpoints are available
#   hubot ltdstatus verbose - Report whether all published product endpoints are available, verbosely
#   hubot ltdstatus <product> - Report whether published product endpoints for <product> are available
#   hubot ltdstatus <product> verbose - Report whether published product endpoints for <product> are available, verbosely 
#   hubot ltdstatus:monitor <interval> - Set up a poll for published product endpoints to run every <interval> seconds
#   hubot ltdstatus:unmonitor - Cancel monitoring poll

timerid = null # static across messages


module.exports = (robot) ->
  rootCas = require('ssl-root-cas/latest').create();
  require('https').globalAgent.options.ca = rootCas;
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
        msg.send "#{arghstr}"
        interval = 1000 * 60 * 60 * 8
      interval = secs * 1000
      loopproducts(robot,msg)
      timerid = setInterval ->
        loopproducts(robot,msg)
      , interval
      msg.send "Product endpoint monitoring enabled: poll #{secs} s."
    else
      msg.send "Product endpoint monitoring already enabled."
    return
  robot.respond /ltdstatus:unmonitor/i, (msg) ->
    if timerid
      clearInterval(timerid)
      msg.send "Product endpoint monitoring disabled."
      timerid = null
    else
      msg.send "Product endpoint monitoring already disabled."
    return


getltdstatus = (robot,msg,product,verbose,interactive) ->
  urlstr="https://api.lsst.codes/productstatus/"
  if product
    urlstr += "#{product}"
  console.log("Getting URL #{urlstr}")
  robot.http(urlstr).get() (err, res, body) ->
    if err
      msg.send "Error: `#{err}`"
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
      msg.send mstr
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
            thisedstr = "`#{vers}`: #{url}"
            if sc < 200 or sc > 299
              aww = ":broken_heart: (`#{sc}`)"
              edstr += "#{aww}"
              if "#{url}" is "#{produrl}" or "#{url}" is "#{produrl}/"
                masterstr += " #{aww}"
            else
              yay = ":white_check_mark:"
              edstr += "#{yay}"
              console.log("url: #{url} / produrl: #{produrl}")
              if "#{url}" is "#{produrl}" or "#{url}" is "#{produrl}/"
                masterstr += " " + yay
            edstr += " #{thisedstr}\n"
        mstr += "#{masterstr}\n#{edstr}"
      console.log("Response:\n@@@@\n#{mstr}\n@@@@")
      msg.send "#{mstr}"
    catch error
      msg.send "Could not get product status."
      msg.send "Error was: `#{error}`"
      msg.send "Body of response was: `#{body}`"


loopproducts = (robot,msg) ->
  getltdstatus(robot,msg,null,false,false)
