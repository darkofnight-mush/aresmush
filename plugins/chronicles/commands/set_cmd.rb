module AresMUSH
  module Chronicles

    class SetCmd
      include CommandHandler

      attr_accessor :stat_name, :value

      def parse_args
        name, val = cmd.args.split("=", 2)

        self.stat_name = name&.strip
        self.value = val&.strip&.to_i
      end

      def check
        return "Usage: set <stat>=<value>" if !stat_name || value.nil?

        stat = Chronicles::Stats.resolve(stat_name)
        return "Invalid stat." if !stat

        return nil
      end

      def handle
        key = Chronicles::Stats.resolve(stat_name)

        enactor.set_attribute("chronicles", key, value)

        client.emit "#{key.capitalize} set to #{value}."
      end

    end
  end
end