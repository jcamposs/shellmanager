# Your starting point for daemon specific classes. This directory is
# already included in your load path, so no need to specify it.

require 'controller'

module ShellManager
  def self.start
    ShellManager::Controller.instance.start
  end

  def self.stop
    ShellManager::Controller.instance.stop
  end
end
