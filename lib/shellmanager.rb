# Your starting point for daemon specific classes. This directory is
# already included in your load path, so no need to specify it.

require 'controller'
require 'erb'

module ShellManager
  def self.render(name, bind)
    msg_dir = File.join(DaemonKit.root, "app", "messages")
    template = ERB.new File.new(File.join(msg_dir, name)).read
    return template.result(bind).split.join(" ")
  end

  def self.start
    ShellManager::Controller.instance.start
  end

  def self.stop
    ShellManager::Controller.instance.stop
  end
end
