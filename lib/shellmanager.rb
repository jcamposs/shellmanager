# Your starting point for daemon specific classes. This directory is
# already included in your load path, so no need to specify it.

require 'shellinabox'
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
      @procs = {}
      @started = true
    end

    def stop
      if not @started
        DaemonKit.logger.error "Error: Controller is not started"
        return
      end

      shutdown
      @procs.values.each { |handler|  handler.stop }
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
          process_start(req)
          #Todo: Send success notification
        rescue Exception => e
          DaemonKit.logger.error e.message
          DaemonKit.logger.error e.backtrace
          #Todo: Send error notification
        end
      end
    end

    def shutdown
      @queue.delete
      @chan.close
    end

    def process_start(req)
      raise "Protocol error" if not req["id"]

      if @procs[req["id"]]
        handler = @procs.delete(req["id"])
        handler.stop
      end

      handler = Shellinabox::Handler.new

      raise "Can't start shellinabox" if not handler.start(req)
      @procs[req["id"]] = handler
    end
  end
end
