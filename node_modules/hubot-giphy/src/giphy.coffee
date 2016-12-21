# Description
#   hubot interface for giphy-api (https://github.com/austinkelleher/giphy-api)
#
# Configuration:
#   HUBOT_GIPHY_API_KEY
#   HUBOT_GIPHY_HTTPS
#   HUBOT_GIPHY_TIMEOUT
#   HUBOT_GIPHY_DEFAULT_LIMIT     default: 5
#   HUBOT_GIPHY_DEFAULT_RATING
#   HUBOT_GIPHY_INLINE_IMAGES
#   HUBOT_GIPHY_MAX_SIZE
#   HUBOT_GIPHY_DEFAULT_ENDPOINT  default: search
#
# Commands:
#   hubot giphy [endpoint] [options...] something interesting - <requests an image relating to "something interesting">
#   hubot giphy help - show giphy plugin usage
#
# Notes:
#   HUBOT_GIPHY_API_KEY: get your api key @ http://api.giphy.com/
#   HUBOT_GIPHY_HTTPS: use https mode (boolean)
#   HUBOT_GIPHY_TIMEOUT: API request timeout (number, in seconds)
#   HUBOT_GIPHY_DEFAULT_LIMIT: max results returned for collection based requests (number)
#   HUBOT_GIPHY_RATING: result rating limitation (string, one of y, g, pg, pg-13, or r)
#   HUBOT_GIPHY_INLINE_IMAGES: images are inlined. i.e. ![giphy](uri) (boolean)
#   HUBOT_GIPHY_DEFAULT_ENDPOINT: endpoint used when none is specified (string)
#
# Author:
#   Pat Sissons[patricksissons@gmail.com]

giphyApi = require 'giphy-api'

DEBUG = process.env.DEBUG

# utility method for extending an object definition
extend = (object, properties) ->
  object = object or { }
  for key, val of properties or { }
    object[key] = val if val or val == ''
  object

# utility method for merging two objects
merge = (options, overrides) ->
  extend (extend {}, options), overrides

class Giphy
  @SearchEndpointName = 'search'
  @IdEndpointName = 'id'
  @TranslateEndpointName = 'translate'
  @RandomEndpointName = 'random'
  @TrendingEndpointName = 'trending'
  @HelpName = 'help'

  @endpoints = [
    Giphy.SearchEndpointName,
    Giphy.IdEndpointName,
    Giphy.TranslateEndpointName,
    Giphy.RandomEndpointName,
    Giphy.TrendingEndpointName,
  ]

  @regex = new RegExp "^\\s*(#{Giphy.endpoints.join('|')}|#{Giphy.HelpName})?\\s*(.*?)$", 'i'

  constructor: (robot, api) ->
    throw new Error 'Robot is required' if not robot
    throw new Error 'Giphy API is required' if not api

    @robot = robot
    @api = api
    @defaultLimit = process.env.HUBOT_GIPHY_DEFAULT_LIMIT or '5'
    @defaultEndpoint = process.env.HUBOT_GIPHY_DEFAULT_ENDPOINT or Giphy.SearchEndpointName

    match = /(~?)(\d+)/.exec (process.env.HUBOT_GIPHY_MAX_SIZE or '0')
    @maxSize = if match then Number match[2] else 0
    @allowLargerThanMaxSize = (match and match[1] == '~')

    @helpText = """
#{@robot.name} giphy [endpoint] [options...] [args]

endpoints: search, id, translate, random, trending
options: rating, limit, offset, api

default endpoint is '#{@defaultEndpoint}' if none is specified
options can be specified using /option:value
rating can be one of y,g, pg, pg-13, or r

Example:
  #{@robot.name} giphy search /limit:100 /offset:50 /rating:pg something to search for
""".trim()

  ### istanbul ignore next ###
  log: ->
    if DEBUG
      [ msg, state, args... ] = arguments
      state = extend({}, state)
      delete state.msg
      args.unshift state
      console.log.call this, msg, args

  error: (msg, reason) =>
    if msg and reason
      @sendMessage msg, reason

  createState: (msg) ->
    if msg
      state = {
        msg: msg
        input: msg.match[1] or ''
        endpoint: undefined
        args: undefined
        options: undefined
        uri: undefined
      }

  match: (input) ->
    Giphy.regex.exec input or ''

  getEndpoint: (state) =>
    @log 'getEndpoint:', state
    match = @match state.input

    if match
      state.endpoint = match[1] or @defaultEndpoint
      state.args = match[2]
    else
      state.endpoint = state.args = ''

  getNextOption: (state) =>
    @log 'getNextOption:', state
    regex = /\/(\w+):(\w*)/
    optionFound = false
    state.args = state.args.replace regex, (match, key, val) ->
      state.options[key] = val
      optionFound = true
      ''
    state.args = state.args.trim()
    optionFound

  # rating, limit, offset, api
  getOptions: (state) =>
    @log 'getOptions:', state
    state.options = {}
    while @getNextOption state
      null

  getRandomResultFromCollectionData: (data, callback) ->
    if data and callback and data.length > 0
      callback(if data.length == 1 then data[0] else data[Math.floor(Math.random() * data.length)])

  getUriFromResultDataWithMaxSize: (images, size = 0, allowLargerThanMaxSize = false) ->
    if images and size > 0
      imagesBySize = Object
        .keys(images)
        .map((x) -> images[x])
        .sort((a, b) -> a.size - b.size)

      # for whatever reason istanbul is complaining about this missing else block
      ### istanbul ignore else ###
      if imagesBySize.length > 0
        image = null
        allowedImages = imagesBySize
          .filter (x) -> x.size <= size

        if allowedImages and allowedImages.length > 0
          image = allowedImages[allowedImages.length - 1]
        else if allowLargerThanMaxSize
          image = imagesBySize[0]

        if image and image.url
          image.url

  getUriFromResultData: (data) =>
    if data and data.images
      if @maxSize > 0
        @getUriFromResultDataWithMaxSize data.images, @maxSize, @allowLargerThanMaxSize
      else if data.images.original
        data.images.original.url

  getUriFromRandomResultData: (data) ->
    if data
      data.url

  getSearchUri: (state) =>
    @log 'getSearchUri:', state
    if state.args and state.args.length > 0
      options = merge {
        q: state.args,
        limit: @defaultLimit
        rating: process.env.HUBOT_GIPHY_DEFAULT_RATING
      }, state.options
      @api.search options, (err, res) =>
        @handleResponse state, err, => @getRandomResultFromCollectionData(res.data, @getUriFromResultData)
    else
      @getRandomUri state

  getIdUri: (state) =>
    @log 'getIdUri:', state
    if state.args and state.args.length > 0
      ids = state.args
        .split(' ')
        .filter((x) -> x.length > 0)
        .map((x) -> x.trim())
      @api.id ids, (err, res) =>
        @handleResponse state, err, => @getRandomResultFromCollectionData(res.data, @getUriFromResultData)
    else
      @error state.msg, 'No Id Provided'

  getTranslateUri: (state) =>
    @log 'getTranslateUri:', state
    options = merge {
      s: state.args,
      rating: process.env.HUBOT_GIPHY_DEFAULT_RATING
    }, state.options
    @api.translate options, (err, res) =>
      @handleResponse state, err, => @getUriFromResultData res.data

  getRandomUri: (state) =>
    @log 'getRandomUri:', state
    options = merge {
      tag: state.args,
      rating: process.env.HUBOT_GIPHY_DEFAULT_RATING
    }, state.options
    @api.random options, (err, res) =>
      @handleResponse state, err, => @getUriFromRandomResultData res.data

  getTrendingUri: (state) =>
    @log 'getTrendingUri:', state
    options = merge {
      limit: @defaultLimit
      rating: process.env.HUBOT_GIPHY_DEFAULT_RATING
    }, state.options
    @api.trending options, (err, res) =>
      @handleResponse state, err, => @getRandomResultFromCollectionData(res.data, @getUriFromResultData)

  getHelp: (state) =>
    @log 'getHelp:', state
    @sendMessage state.msg, @helpText

  getUri: (state) =>
    @log 'getUri:', state
    switch state.endpoint
      when Giphy.SearchEndpointName then @getSearchUri state
      when Giphy.IdEndpointName then @getIdUri state
      when Giphy.TranslateEndpointName then @getTranslateUri state
      when Giphy.RandomEndpointName then @getRandomUri state
      when Giphy.TrendingEndpointName then @getTrendingUri state
      when Giphy.HelpName then @getHelp state
      else @error state.msg, "Unrecognized Endpoint: #{state.endpoint}"

  handleResponse: (state, err, uriCreator) =>
    @log 'handleResponse:', state
    if err
      @error state.msg, "giphy-api Error: #{err}"
    else
      state.uri = uriCreator.call this
      @sendResponse state

  sendResponse: (state) =>
    @log 'sendResponse:', state
    if state.uri
      message = if process.env.HUBOT_GIPHY_INLINE_IMAGES then "![giphy](#{state.uri})" else state.uri
      @sendMessage state.msg, message
    else
      @error state.msg, 'No Results Found'

  sendMessage: (msg, message) ->
    if msg and message
      msg.send message

  respond: (msg) =>
    # we must check the match.length >= 2 here because just checking the value
    # match[2] could give us a false negative since empty string resolves to false
    if msg and msg.match and msg.match.length >= 2
      state = @createState msg

      @getEndpoint state
      @getOptions state

      @getUri state
    else
      @error msg, "I Didn't Understand Your Request"

module.exports = (robot) ->
  api = giphyApi({
    https: (process.env.HUBOT_GIPHY_HTTPS is 'true') or false
    timeout: Number(process.env.HUBOT_GIPHY_TIMEOUT) or null
    apiKey: process.env.HUBOT_GIPHY_API_KEY
  })

  giphy = new Giphy robot, api

  robot.respond /giphy\s*(.*?)\s*$/, (msg) ->
    giphy.respond msg

  # this allows testing to instrument the giphy instance
  ### istanbul ignore next ###
  if global and global.IS_TESTING
    giphy

# this allows testing to instrument the giphy class
### istanbul ignore next ###
if global and global.IS_TESTING
  module.exports.Giphy = Giphy
  module.exports.extend = extend
  module.exports.merge = merge
