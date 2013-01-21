module Shellinabox
  class Handler
    def start req
      DaemonKit.logger.debug "Start shellinabox process"

      return false if not configure(req)

      exec_shellinabox
      return true
    end

    def stop
      DaemonKit.logger.debug "Stop shellinabox process #{@pid}"
      begin
        Process.kill('TERM', @pid)
      rescue Exception => e
        DaemonKit.logger.error e.message
        DaemonKit.logger.error e.backtrace
      end
    end

    private
    def configure(req)
      return false if not req["id"]
      return false if not req["user_id"]
      return false if not req["vm_port"]
      return false if not req["vm_proxy"]

      @id = req["id"]
      @user_id = req["user_id"]
      @vm_port = req["vm_port"]
      @vm_proxy = req["vm_proxy"]
      return true
    end

    def exec_shellinabox
      # service option
      svc = "telnet #{@vm_proxy} #{@vm_port} -l #{@user_id}"
      svc_opt = "/:#{DAEMON_CONF[:user]}:#{DAEMON_CONF[:group]}:HOME:#{svc}"

      # css options
      wob = "00_White\ On\ Black.css"
      bow = "00+Black\ on\ White.css"
      color = "01+Color\ Terminal.css"
      monochrome = "01_Monochrome.css"

      enabled_dir = File.join(DAEMON_CONF[:path], "options-enabled")

      css_opt = "Normal:+#{File.join(enabled_dir, wob)},"
      css_opt += "Reverse:-#{File.join(enabled_dir, bow)};"
      css_opt += "Color:+#{File.join(enabled_dir, color)},"
      css_opt += "Monochrome:-#{File.join(enabled_dir, monochrome)}"

      # Reserve a free port by using it, afterwads we will release it
      # at the time of launching the shellinabox demon. That's not an infallible
      # fix due to the port can be reassigned to a different process in the
      # time it is realeased and assigned again.
      svc = TCPServer.new 0
      port = svc.addr[1]

      # Release the port so that it can be used by shellinabox demon
      # Note: This port can be reassigned to a diferent process if a context
      # switch happens altough it's not very likely getting the same port.
      svc.close

      @pid = EM.system "shellinaboxd", "--disable-ssl", "--port=#{port}",
         "--user=#{DAEMON_CONF[:user]}", "--group=#{DAEMON_CONF[:group]}",
         "--service=#{svc_opt}", "--user-css=#{css_opt}"
    end
  end
end
