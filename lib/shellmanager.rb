# Your starting point for daemon specific classes. This directory is
# already included in your load path, so no need to specify it.

require 'singleton'
require 'json'

module ShellManager
  class Controller
    include Singleton

    def start
      if @started
        DaemonKit.logger.error "Error: Controller already started"
        return
      end

      init
      @started = true
    end

    def stop
      if not @started
        DaemonKit.logger.error "Error: Controller is not started"
        return
      end

      shutdown
      @started = false
    end

    private
    def init
      @chan = AMQP::Channel.new
      queue_name = "#{DAEMON_CONF[:root_service]}.start"
      DaemonKit.logger.debug "Creating queue #{queue_name}"
      @queue = @chan.queue(queue_name, :durable => true)

      @queue.subscribe do |metadata, payload|
        DaemonKit.logger.debug "[requests] start shellinabox #{payload}."
        begin
          req = JSON.parse(payload)
          # TODO: Start shellinabox process
        rescue Exception => e
          DaemonKit.logger.error e.message
          DaemonKit.logger.error e.backtrace
        end
      end
    end

    def shutdown
      @queue.delete
      @chan.close
    end
  end
end
