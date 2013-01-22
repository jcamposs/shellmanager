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

      init_daemon_phase1
    end

    def stop
      if not @started
        DaemonKit.logger.error "Error: Controller is not started"
        return
      end

      @procs.values.each do |handler|
        # Daemon is shutting down so we can not use AMQP to notify dead processes
        handler.on_finish do |pid|
          DaemonKit.logger.debug "Ignored process #{pid}"
        end
        handler.stop
      end

      shutdown_amqp
      store_ids
      @started = false
    end

    private
    def init_daemon_phase1
      DaemonKit.logger.debug "Initializing daemon phase 1"
      ids = load_ids

      if not ids
        init_daemon_phase2
        return
      end

      FileUtils.rm(File.join(DaemonKit.root, "log", "ids"))

      # Notify dead processes
      DaemonKit.logger.debug "Send stop notification for ids: #{ids}"
      @chan = AMQP::Channel.new
      send_stop_msg ids do
        init_daemon_phase2
      end
    end

    def init_daemon_phase2
      DaemonKit.logger.debug "Initializing daemon phase 2"
      init_amqp
      @procs = {}
      @started = true
    end

    def load_ids
      return if not File.exist?(File.join(DaemonKit.root, "log", "ids"))
      begin
        DaemonKit.logger.debug "Daemon shutted down with pending notifications"

        file = File.new(File.join(DaemonKit.root, "log", "ids"), "r")
        ids = Marshal.load file
      rescue Exception => e
        DaemonKit.logger.error "Can't write ids file: #{e.message}"
        DaemonKit.logger.debug e.backtrace
      ensure
        file.close
      end

      return ids
    end

    def store_ids
      return if @procs.keys.length == 0
      begin
        DaemonKit.logger.debug "Store shellinabox ids that must be notified next time the daemon starts"
        DaemonKit.logger.debug "Ids: #{@procs.keys}"

        file = File.new(File.join(DaemonKit.root, "log", "ids"), "w")
        file.write Marshal.dump(@procs.keys)
      rescue Exception => e
        DaemonKit.logger.error "Can't write ids file: #{e.message}"
        DaemonKit.logger.debug e.backtrace
      ensure
        file.close
      end
    end

    def init_amqp
      @chan = AMQP::Channel.new if not @chan
      init_start_queue
      init_stop_queue
    end

    def shutdown_amqp
      shutdown_start_amqp
      shutdown_stop_amqp
      @chan.close
    end

    def init_start_queue
      #Start queue is a work queue used for distributing tasks among workers
      queue_name = "#{DAEMON_CONF[:root_service]}.start"
      DaemonKit.logger.debug "Creating queue #{queue_name}"
      @start_queue = @chan.queue(queue_name, :durable => true)

      @start_queue.subscribe do |metadata, payload|
        DaemonKit.logger.debug "[requests] start shellinabox #{payload}."
        begin
          req = JSON.parse(payload)
          start_process(req)
          #Todo: Send success notification
        rescue Exception => e
          DaemonKit.logger.error e.message
          DaemonKit.logger.error e.backtrace
          #Todo: Send error notification
        end
      end
    end

    def shutdown_start_amqp
      @start_queue.delete
    end

    def init_stop_queue
      #Stop queue is a publish/subscriber queue
      name = "#{DAEMON_CONF[:root_service]}.stop"
      @stop_exchange = @chan.fanout(name)
      @stop_queue = @chan.queue("", :exclusive => true, :auto_delete => true).bind(@stop_exchange)
      @stop_queue.subscribe do |metadata, payload|
        DaemonKit.logger.debug "[requests] stop shellinabox #{payload}."
        begin
          req = JSON.parse(payload)
          stop_process(req)
        rescue Exception => e
          DaemonKit.logger.error e.message
          DaemonKit.logger.error e.backtrace
        end
      end
    end

    def shutdown_stop_amqp
      @stop_queue.delete
      @stop_exchange.delete
    end

    def start_process(req)
      raise "Protocol error" if not req["id"]

      if @procs[req["id"]]
        handler = @procs.delete(req["id"])
        handler.on_finish do |pid|
          DaemonKit.logger.debug "Ignored process #{pid}"
        end
        handler.stop
      end

      handler = Shellinabox::Handler.new
      handler.on_finish do
        @procs.delete(req["id"])
        send_stop_msg([req["id"]])
      end

      raise "Can't start shellinabox" if not handler.start(req)
      @procs[req["id"]] = handler
    end

    def stop_process(req)
      return if not req["id"]

      return if not @procs[req["id"]]

      @procs[req["id"]].stop
    end

    def send_stop_msg(ids)
      ids = ids
      json = ShellManager.render("shellinabox_stopped.js.erb", binding)
      name = "netlab.services.#{DAEMON_ENV}.shellinabox.stopped"
      @chan.default_exchange.publish(json, {:routing_key => name, :content_type => "application/json"}) do
        yield if block_given?
      end
    end
  end
end
