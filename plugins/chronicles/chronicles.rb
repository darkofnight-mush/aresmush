module AresMUSH
  module Chronicles

    require "erb"

    $:.unshift File.dirname(__FILE__)

    require_relative "commands/roll_cmd"
    require_relative "commands/stat_cmd"
    require_relative "commands/stats_cmd"
    require_relative "models/stats"

    def self.plugin_dir
      File.dirname(__FILE__)
    end

    def self.shortcuts
      Global.read_config("chronicles", "shortcuts")
    end

    def self.get_cmd_handler(client, cmd, enactor)
      case cmd.root
      when "roll"
        return RollCmd

      when "stat"
        return StatCmd

      when "stats"
        return StatsCmd

      when "set"
        return SetCmd
      end

      return nil
    end

    def self.get_event_handler(event_name)
      nil
    end

    def self.get_web_request_handler(request)
      nil
    end

  end
end