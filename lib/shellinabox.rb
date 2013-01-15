module Shellinabox
  class Handler
    def start req
      DaemonKit.logger.debug "Start shellinabox process"
      return false if not configure(req)

      return true
    end

    def stop
      DaemonKit.logger.debug "Stop shellinabox process"
    end

    private
    def configure(req)
      return false if not req["id"]
      return false if not req["user_id"]
      return false if not req["vm_port"]
      return false if not req["vm_proxy"]

      @id = req["id"]
      @user = req["user_id"]
      @vm_port = req["vm_port"]
      @vm_proxy = req["vm_proxy"]
      return true
    end
  end
end
