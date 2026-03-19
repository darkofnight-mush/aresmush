module AresMUSH
  module Chronicles

    class Stats

      # ------------------------------------------------------------
      # LOAD YAML
      # ------------------------------------------------------------
      def self.load_yaml(file)
        path = File.join(Chronicles.plugin_dir, "config", "stats", file)
        YAML.load_file(path)
      end

      # ------------------------------------------------------------
      # RAW DATA
      # ------------------------------------------------------------
      def self.attributes
        @attributes ||= load_yaml("attributes.yml")
      end

      def self.skills
        @skills ||= load_yaml("skills.yml")
      end

      def self.derived
        @derived ||= load_yaml("derived.yml")
      end

      # ------------------------------------------------------------
      # NEW: SPLAT HELPERS
      # ------------------------------------------------------------

      def self.get_splat(char)
        return nil if !char
        char.get_attribute("chronicles", "splat")
      end

      def self.splat_groups(char)
        splat = get_splat(char)
        return [] if !splat

        data = Loader.splat(splat)
        return [] if !data

        data.values
      end

      # ------------------------------------------------------------
      # FLATTENED LOOKUP TABLE
      # ------------------------------------------------------------
      def self.all_stats
        @all_stats ||= begin
          combined = {}

          [attributes, skills, derived].each do |group|
            next if !group

            group.each do |category, stats|
              next if category == "metadata"
              next if !stats.is_a?(Hash)

              stats.each do |name, data|
                next if !data.is_a?(Hash)

                key = name.to_s.downcase
                combined[key] = data.merge("category" => category)
              end
            end
          end

          combined
        end
      end

      # ------------------------------------------------------------
      # NEW: CHARACTER-AWARE STAT TABLE
      # ------------------------------------------------------------
      def self.all_stats_for(char)
        combined = all_stats.dup

        splat_groups(char).each do |group|
          next if !group

          group.each do |category, stats|
            next if category == "metadata"
            next if !stats.is_a?(Hash)

            stats.each do |name, data|
              next if !data.is_a?(Hash)

              key = name.to_s.downcase
              combined[key] = data.merge("category" => category)
            end
          end
        end

        combined
      end

      # ------------------------------------------------------------
      # RESOLVE NAME OR ABBREV
      # ------------------------------------------------------------
      def self.resolve(name, char = nil)
        return nil if !name

        key = name.downcase

        stats = char ? all_stats_for(char) : all_stats

        stats.each do |stat, data|
          return stat if stat == key
          return stat if data["abbrev"]&.downcase == key
        end

        nil
      end

      # ------------------------------------------------------------
      # GET STAT DATA
      # ------------------------------------------------------------
      def self.get_stat(name, char = nil)
        key = resolve(name, char)
        return nil if !key

        stats = char ? all_stats_for(char) : all_stats
        stats[key]
      end

      # ------------------------------------------------------------
      # GET CHARACTER STAT VALUE (REDIS-BACKED)
      #
      # This is the bridge between:
      # - YAML stat definitions (what stats exist)
      # - Character data (what values a character has)
      #
      # Uses Ares attribute storage:
      #   char.set_attribute("chronicles", "dexterity", 3)
      #
      # Returns:
      # - Integer value if set
      # - 0 if not set (safe default for dice math)
      # - nil if stat is invalid
      #
      # SAFE TO MODIFY:
      # - Hook in derived stat calculation later
      # - Add validation hooks
      #
      # ------------------------------------------------------------
      def self.get(char, stat_name)
        return nil if !char

        key = resolve(stat_name, char)
        return nil if !key

        stats = all_stats_for(char)

        # --- Derived stat support ---
        stat_data = stats[key]
        if stat_data && stat_data["formula"]
          return evaluate_formula(char, stat_data["formula"])
        end

        val = char.get_attribute("chronicles", key)

        return val.to_i if val
        return 0
      end

      # ------------------------------------------------------------
      # FORMULA EVALUATION
      #
      # Supports:
      # - min(a, b)
      # - addition (+)
      # - integers
      # - stat references
      #
      # Example:
      #   "min(dexterity, wits) + athletics"
      #
      # NOTE:
      # This is intentionally simple and safe (no eval).
      # Extend cautiously if adding new operators.
      #
      # ------------------------------------------------------------
      def self.evaluate_formula(char, formula)
        return 0 if !formula

        expr = formula.dup

        # Handle min(a, b)
        expr.gsub!(/min\(([^,]+),([^)]+)\)/i) do
          a = evaluate_term(char, $1.strip)
          b = evaluate_term(char, $2.strip)
          [a, b].min.to_s
        end

        # Handle addition
        tokens = expr.split("+").map(&:strip)

        total = 0
        tokens.each do |token|
          total += evaluate_term(char, token)
        end

        total
      end

      # ------------------------------------------------------------
      # TERM EVALUATION
      #
      # Resolves:
      # - integers
      # - stat names
      #
      # ------------------------------------------------------------
      def self.evaluate_term(char, token)
        return 0 if !token

        return token.to_i if token.match?(/^\d+$/)

        key = resolve(token, char)
        return 0 if !key

        val = char.get_attribute("chronicles", key)
        return val.to_i if val

        0
      end

      # ------------------------------------------------------------
      # GROUPED OUTPUT (for stats command)
      # ------------------------------------------------------------
      def self.grouped
        {
          attributes: attributes.reject { |k, _| k == "metadata" },
          skills: skills.reject { |k, _| k == "metadata" },
          derived: derived.reject { |k, _| k == "metadata" }
        }
      end

    end
  end
end