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

      init_amqp
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
    def init_amqp
      init_start_queue
      init_stop_queue
    end

    def init_start_queue
      #Start queue is a work queue used for distributing tasks among workers
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

    def init_stop_queue
      #Stop queue is a publish/subscriber queue
      @stop_chan = AMQP::Channel.new
      name = "#{DAEMON_CONF[:root_service]}.stop"

      @stop_exchange = @stop_chan.fanout(name)
      @stop_queue = @stop_chan.queue("", :exclusive => true, :auto_delete => true).bind(@stop_exchange)
      @stop_queue.subscribe do |metadata, payload|
        DaemonKit.logger.debug "[requests] stop shellinabox #{payload}."
        begin
          req = JSON.parse(payload)
          send_stop_msg if process_stop(req)
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

    def process_stop(req)
      raise "Protocol error" if not req["id"]

      return false if not @procs[req["id"]]

      handler = @procs.delete(req["id"])
      handler.stop
      return true
    end

    def send_stop_msg
      DaemonKit.logger.debug "Send stop message"
    end
  end
end
