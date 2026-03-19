module AresMUSH
  module Chronicles

    class StatCmd
      include CommandHandler

      attr_accessor :stat_name

      def parse_args
        self.stat_name = cmd.args&.strip
      end

      def check
        return "Which stat?" if !stat_name

        # --- UPDATED: pass enactor for splat-aware lookup ---
        stat_data = Chronicles::Stats.get_stat(stat_name, enactor)
        return "Stat not found." if !stat_data

        nil
      end

      def handle
        # --- UPDATED: resolve + fetch using enactor ---
        name = Chronicles::Stats.resolve(stat_name, enactor)
        stat_data = Chronicles::Stats.get_stat(stat_name, enactor)

        # --- SAFETY: avoid titleize crash ---
        return client.emit("Stat not found.") if !name || !stat_data

        client.emit "#{name.titleize}"
        client.emit "Category: #{stat_data['category']}"

        if stat_data['abbrev']
          client.emit "Abbrev: #{stat_data['abbrev']}"
        end

        client.emit "Description: #{stat_data['description']}" if stat_data['description']
        client.emit "Page: #{stat_data['page']}" if stat_data['page']
      end

    end
  end
end