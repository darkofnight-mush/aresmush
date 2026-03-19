module AresMUSH
  module Chronicles

    class StatsCmd
      include CommandHandler

      def handle
        grouped = Chronicles::Stats.grouped

        client.emit "=== Attributes ==="

        grouped[:attributes].each do |category, stats|
          client.emit "#{category.titleize}:"

          names = stats.keys.map { |k| k.split('_').map(&:capitalize).join(' ') }
          client.emit names.join(", ")
          client.emit ""
        end

        client.emit "=== Skills ==="

        grouped[:skills].each do |category, stats|
          client.emit "#{category.titleize}:"

          names = stats.keys.map { |k| k.split('_').map(&:capitalize).join(' ') }
          client.emit names.join(", ")
          client.emit ""
        end
      end

    end
  end
end