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
      # SPLAT HELPERS
      # ------------------------------------------------------------
      def self.get_splat(char)
        return nil if !char
        cc = ChroniclesChar.for_char(char)
        data = cc.chronicles || {}
        data["splat"]
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
      # CHARACTER-AWARE STAT TABLE
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
      # RESOLVE NAME (SAFE + UX FRIENDLY)
      # ------------------------------------------------------------
      def self.resolve_stat(name, char = nil)
        return { error: :no_input } if !name
        return { error: :invalid_type } unless name.is_a?(String)

        key = name.downcase.strip

        stats = char ? all_stats_for(char) : all_stats

        matches = stats.select do |stat, data|
          next false unless stat.is_a?(String)

          stat == key ||
          data["abbrev"]&.downcase == key ||
          (key.length >= 3 && stat.start_with?(key))
        end.keys

        return { stat: matches.first } if matches.size == 1
        return { error: :not_found } if matches.empty?

        { error: :ambiguous, matches: matches }
      end

      # ------------------------------------------------------------
      # GET STAT DATA
      # ------------------------------------------------------------
      def self.get_stat(name, char = nil)
        result = resolve_stat(name, char)
        return nil if result[:error]

        key = result[:stat]
        stats = char ? all_stats_for(char) : all_stats
        stats[key]
      end

      # ------------------------------------------------------------
      # GET CHARACTER STAT VALUE
      # ------------------------------------------------------------
      def self.get(char, stat_name)
        return nil if !char

        result = resolve_stat(stat_name, char)
        return 0 if result[:error]

        key = result[:stat]

        stats = all_stats_for(char)

        stat_data = stats[key]
        if stat_data && stat_data["formula"]
          return evaluate_formula(char, stat_data["formula"])
        end

        cc = ChroniclesChar.for_char(char)
        data = cc.chronicles || {}
        val = data[key]

        return val.to_i if val
        return 0
      end

      # ------------------------------------------------------------
      # FORMULA EVALUATION
      # ------------------------------------------------------------
      def self.evaluate_formula(char, formula)
        return 0 if !formula

        expr = formula.dup

        expr.gsub!(/min\(([^,]+),([^)]+)\)/i) do
          a = evaluate_term(char, $1.strip)
          b = evaluate_term(char, $2.strip)
          [a, b].min.to_s
        end

        tokens = expr.split("+").map(&:strip)

        total = 0
        tokens.each do |token|
          total += evaluate_term(char, token)
        end

        total
      end

      # ------------------------------------------------------------
      # TERM EVALUATION
      # ------------------------------------------------------------
      def self.evaluate_term(char, token)
        return 0 if !token

        return token.to_i if token.match?(/^\d+$/)

        result = resolve_stat(token, char)
        return 0 if result[:error]

        key = result[:stat]

        cc = ChroniclesChar.for_char(char)
        data = cc.chronicles || {}
        val = data[key]

        return val.to_i if val
        return 0
      end

      # ------------------------------------------------------------
      # GROUPED OUTPUT
      # ------------------------------------------------------------
      def self.grouped
        {
          attributes: attributes.reject { |k, _| k == "metadata" },
          skills: skills.reject { |k, _| k == "metadata" },
          derived: derived.reject { |k, _| k == "metadata" }
        }
      end

      # ------------------------------------------------------------
      # SPECIALTIES
      # ------------------------------------------------------------

      # Normalize specialty input (handles spaces, casing)
      def self.normalize_specialty(name)
        return nil if !name
        name.to_s.downcase.strip.gsub(/\s+/, "_")
      end

      def self.specialties_for(char, stat)
        cc = ChroniclesChar.for_char(char)
        data = cc.chronicles || {}

        specs = data["specialties"] || {}
        stat_specs = specs[stat.to_s] || {}

        stat_specs.keys
      end

      def self.specialty_active?(char, stat, name)
        cc = ChroniclesChar.for_char(char)
        data = cc.chronicles || {}

        specs = data["specialties"] || {}
        stat_specs = specs[stat.to_s] || {}

        stat_specs[name.to_s].to_i > 0
      end

      # Resolve specialty like stats (prefix matching, ambiguity safe)
      def self.resolve_specialty(char, stat, input)
        return nil if !char || !stat || !input

        input = normalize_specialty(input)

        specs = specialties_for(char, stat)

        matches = specs.select do |s|
          s == input || s.start_with?(input)
        end

        return matches.first if matches.size == 1
        return nil if matches.empty?

        { error: :ambiguous, matches: matches }
      end

      def self.set_specialty(char, stat, name, value)
        cc = ChroniclesChar.for_char(char)
        data = cc.chronicles || {}

        name = normalize_specialty(name)

        data["specialties"] ||= {}
        data["specialties"][stat] ||= {}

        if value.to_i > 0
          data["specialties"][stat][name] = 1
        else
          data["specialties"][stat].delete(name)
          data["specialties"].delete(stat) if data["specialties"][stat].empty?
        end

        cc.update(chronicles: data)
      end

    end
  end
end