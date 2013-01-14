# Your starting point for daemon specific classes. This directory is
# already included in your load path, so no need to specify it.

module ShellManager
  def self.start
    DaemonKit.logger.debug "Starting the service"
  end

  def self.stop
    DaemonKit.logger.debug "Stopping the service"
  end
end
