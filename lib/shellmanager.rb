# Your starting point for daemon specific classes. This directory is
# already included in your load path, so no need to specify it.

require 'singleton'

module ShellManager
  class Controller
    include Singleton

    def start
      if @started
        DaemonKit.logger.error "Error: Controller already started"
        return
      end

      @started = true
    end

    def stop
      if not @started
        DaemonKit.logger.error "Error: Controller is not started"
        return
      end

      @started = false
    end
  end
end
