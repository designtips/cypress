## store the cwd
cwd = process.cwd()

path     = require("path")
_        = require("lodash")
os       = require("os")
chalk    = require("chalk")
Promise  = require("bluebird")
minimist = require("minimist")
zip      = require("./zip")
ask      = require("./ask")
bump     = require("./bump")
meta     = require("./meta")
build    = require("./build")
upload   = require("./upload")
Base     = require("./base")
Linux    = require("./linux")
Darwin   = require("./darwin")

success = (str) ->
  console.log chalk.bgGreen(" " + chalk.black(str) + " ")

fail = (str) ->
  console.log chalk.bgRed(" " + chalk.black(str) + " ")

zippedFilename = (platform) ->
  # TODO use .tar.gz for linux archive. For now to preserve
  # same file format as before use .zip
  if platform == "linux" then "cypress.zip" else "cypress.zip"

## hack for @packages/server modifying cwd
process.chdir(cwd)

askWhichPlatform = (platform) ->
  ## if we already have a platform
  ## just resolve with that
  if platform
    return Promise.resolve(platform)

  ## else go ask for it!
  ask.whichPlatform()

askWhichVersion = (version) ->
  ## if we already have a version
  ## just resolve with that
  if version
    return Promise.resolve(version)

  ## else go ask for it!
  ask.deployNewVersion()

deploy = {
  zip:    zip
  ask:    ask
  meta:   meta
  upload: upload
  Base:   Base
  Darwin: Darwin
  Linux:  Linux

  # getPlatform: (platform, options) ->
  #   platform ?= os.platform()
  #
  #   Platform = @[platform.slice(0, 1).toUpperCase() + platform.slice(1)]
  #
  #   throw new Error("Platform: '#{platform}' not found") if not Platform
  #
  #   options ?= @parseOptions(process.argv.slice(2))
  #
  #   (new Platform(platform, options))

  parseOptions: (argv) ->
    opts = minimist(argv)
    opts.runTests = false if opts["skip-tests"]
    opts

  # build: (platform) ->
  #   ## read off the argv
  #   options = @parseOptions(process.argv)
  #
  #   @getPlatform(platform?.osName, options).build()

  bump: ->
    ask.whichBumpTask()
    .then (task) ->
      switch task
        when "run"
          bump.run()
        when "version"
          ask.whichVersion(meta.distDir)
          .then (v) ->
            bump.version(v)

  release: ->
    ## read off the argv
    options = @parseOptions(process.argv)

    release = (version) =>
      upload.s3Manifest(version)
      .then ->
        success("Release Complete")
      .catch (err) ->
        fail("Release Failed")
        reject(err)

    if v = options.version
      release(v)
    else
      ask.whichRelease(meta.distDir)
      .then(release)

  deploy: ->
    ## read off the argv
    # to skip further questions like platform and version
    # pass these as options like this
    #   npm run deploy -- --platform darwin --version 0.20.0
    options = @parseOptions(process.argv)

    askWhichPlatform(options.platform)
    .then (platform) ->
      askWhichVersion(options.version)
      .then (version) ->
        # options.version = version
        build(platform, version)
        # .return([platform, version])
    # .spread (platform, version) ->

        # @getPlatform(plat, options).deploy()
      # .then (platform) =>
      .then (built) =>
        console.log(built)
        src  = built.buildDir
        dest = path.resolve(zippedFilename(platform))
        zip.ditto(src, dest)
      .then (zippedFilename) =>
        console.log("Need to upload file %s", zippedFilename)
        # upload.toS3(platform)
        #   .then ->
        #     success("Dist Complete")
        #   .catch (err) ->
        #     fail("Dist Failed")
        #     console.log(err)

}

module.exports = _.bindAll(deploy, _.functions(deploy))