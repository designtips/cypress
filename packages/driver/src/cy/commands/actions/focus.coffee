_ = require("lodash")
Promise = require("bluebird")

$Log = require("../../../cypress/log")
{ delay, dispatchPrimedChangeEvents, focusable } = require("./utils")
utils = require("../../../cypress/utils")

module.exports = (Cypress, Commands) ->

  Commands.addAll({ prevSubject: "dom" }, {
    focus: (subject, options = {}) ->
      ## we should throw errors by default!
      ## but allow them to be silenced
      _.defaults options,
        $el: subject
        error: true
        log: true
        verify: true

      @ensureDom(options.$el, "focus")

      if options.log
        options._log = $Log.command
          $el: options.$el
          consoleProps: ->
            "Applied To": utils.getDomElements(options.$el)

      ## http://www.w3.org/TR/html5/editing.html#specially-focusable
      ## ensure there is only 1 dom element in the subject
      ## make sure its allowed to be focusable
      if not (options.$el.is(focusable) or utils.hasWindow(options.$el))
        return if options.error is false

        node = utils.stringifyElement(options.$el)
        utils.throwErrByPath("focus.invalid_element", {
          onFail: options._log
          args: { node }
        })

      if (num = options.$el.length) and num > 1
        return if options.error is false

        utils.throwErrByPath("focus.multiple_elements", {
          onFail: options._log
          args: { num }
        })

      timeout = @_timeout() * .90

      cleanup = null
      hasFocused = false

      promise = new Promise (resolve, reject) =>
        ## we need to bind to the focus event here
        ## because some browsers will not ever fire
        ## the focus event if the window itself is not
        ## currently focused. so we have to tell our users
        ## to do just that!
        cleanup = ->
          options.$el.off("focus", focused)

        focused = =>
          hasFocused = true

          ## set this back to null unless we are
          ## force focused ourselves during this command
          forceFocusedEl = @state("forceFocusedEl")
          @state("forceFocusedEl", null) unless forceFocusedEl is options.$el.get(0)

          cleanup()

          @_timeout(delay, true)

          Promise
            .delay(delay)
            .then(resolve)

        options.$el.on("focus", focused)

        options.$el.get(0).focus()

        @defer =>
          ## fallback if our focus event never fires
          ## to simulate the focus + focusin
          return if hasFocused

          simulate = =>
            @state("forceFocusedEl", options.$el.get(0))

            ## todo handle relatedTarget's per the spec
            focusinEvt = new FocusEvent "focusin", {
              bubbles: true
              view: @privateState("window")
              relatedTarget: null
            }

            focusEvt = new FocusEvent "focus", {
              view: @privateState("window")
              relatedTarget: null
            }

            ## not fired in the correct order per w3c spec
            ## because chrome chooses to fire focus before focusin
            ## and since we have a simulation fallback we end up
            ## doing it how chrome does it
            ## http://www.w3.org/TR/DOM-Level-3-Events/#h-events-focusevent-event-order
            options.$el.get(0).dispatchEvent(focusEvt)
            options.$el.get(0).dispatchEvent(focusinEvt)
            # options.$el.cySimulate("focus")
            # options.$el.cySimulate("focusin")

          @execute("focused", {log: false, verify: false}).then ($focused) =>
            ## only blur if we have a focused element AND its not
            ## currently ourselves!
            if $focused and $focused.get(0) isnt options.$el.get(0)

              @execute("blur", {$el: $focused, error: false, verify: false, log: false}).then =>
                simulate()
            else
              simulate()

          ## need to catch potential errors from blur
          ## here and reject the promise
          .catch (err) ->
            reject(err)

      promise
        .timeout(timeout)
        .catch Promise.TimeoutError, (err) =>
          cleanup()

          return if options.error is false

          utils.throwErrByPath "focus.timed_out", { onFail: options._log }
        .then =>
          return options.$el if options.verify is false

          do verifyAssertions = =>
            @verifyUpcomingAssertions(options.$el, options, {
              onRetry: verifyAssertions
        })

    blur: (subject, options = {}) ->
      ## we should throw errors by default!
      ## but allow them to be silenced
      _.defaults options,
        $el: subject
        error: true
        log: true
        verify: true
        force: false

      if options.log
        ## figure out the options which actually change the behavior of clicks
        deltaOptions = utils.filterOutOptions(options)

        options._log = $Log.command
          $el: options.$el
          message: deltaOptions
          consoleProps: ->
            "Applied To": utils.getDomElements(options.$el)

      @ensureDom(options.$el, "blur", options._log)

      if (num = options.$el.length) and num > 1
        return if options.error is false

        utils.throwErrByPath("blur.multiple_elements", {
          onFail: options._log
          args: { num }
        })

      @execute("focused", {log: false, verify: false}).then ($focused) =>
        if options.force isnt true and not $focused
          return if options.error is false

          utils.throwErrByPath("blur.no_focused_element", { onFail: options._log })

        if options.force isnt true and options.$el.get(0) isnt $focused.get(0)
          return if options.error is false

          node = utils.stringifyElement($focused)
          utils.throwErrByPath("blur.wrong_focused_element", {
            onFail: options._log
            args: { node }
          })

        timeout = @_timeout() * .90

        cleanup = null
        hasBlurred = false

        promise = new Promise (resolve) =>
          ## we need to bind to the blur event here
          ## because some browsers will not ever fire
          ## the blur event if the window itself is not
          ## currently focused. so we have to tell our users
          ## to do just that!
          cleanup = ->
            options.$el.off("blur", blurred)

          blurred = =>
            hasBlurred = true

            ## set this back to null unless we are
            ## force blurring ourselves during this command
            blacklistFocusedEl = @state("blacklistFocusedEl")
            @state("blacklistFocusedEl", null) unless blacklistFocusedEl is options.$el.get(0)

            cleanup()

            @_timeout(delay, true)

            Promise
              .delay(delay)
              .then(resolve)

          options.$el.on("blur", blurred)

          ## for simplicity we allow change events
          ## to be triggered by a manual blur
          dispatchPrimedChangeEvents.call(@)

          options.$el.get(0).blur()

          @defer =>
            ## fallback if our blur event never fires
            ## to simulate the blur + focusout
            return if hasBlurred

            @state("blacklistFocusedEl", options.$el.get(0))

            ## todo handle relatedTarget's per the spec
            focusoutEvt = new FocusEvent "focusout", {
              bubbles: true
              cancelable: false
              view: @privateState("window")
              relatedTarget: null
            }

            blurEvt = new FocusEvent "blur", {
              bubble: false
              cancelable: false
              view: @privateState("window")
              relatedTarget: null
            }

            options.$el.get(0).dispatchEvent(blurEvt)
            options.$el.get(0).dispatchEvent(focusoutEvt)

        promise
          .timeout(timeout)
          .catch Promise.TimeoutError, (err) =>
            cleanup()

            return if options.error is false

            utils.throwErrByPath "blur.timed_out", { onFail: command }
          .then =>
            return options.$el if options.verify is false

            do verifyAssertions = =>
              @verifyUpcomingAssertions(options.$el, options, {
                onRetry: verifyAssertions
          })
  })