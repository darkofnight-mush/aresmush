module AresMUSH
  module Chronicles

    #
    # ============================================================
    # SET COMMAND
    #
    # Supports:
    #
    #   set Dex=3
    #   set Athletics=2
    #   set Firearms.Shooting=1
    #
    # STAT SETTING:
    #   set <stat>=<value>
    #
    # SPECIALTY SETTING:
    #   set <stat>.<specialty>=<value>
    #
    # ============================================================
    #
    # DESIGN GOALS:
    # - Simple syntax for stat and specialty management
    # - Validation through Chronicles::Stats.resolve_stat
    # - Specialty handling with dot notation
    #
    # ============================================================
    #
    # SAFE TO MODIFY:
    # - Add new validation in check method
    # - Modify success messages in handle method
    #
    # DO NOT:
    # - Change the core stat/specialty storage logic
    # - Break the dot notation parsing
    #
    # ============================================================

    class SetCmd
      include CommandHandler

      attr_accessor :stat_name, :value

      # ============================================================
      # PARSE ARGS
      #
      # Breaks command into:
      # - stat_name (with optional specialty)
      # - value (integer)
      #
      # Supports dot notation for specialties:
      #   "Dex" → base stat
      #   "Firearms.Shooting" → specialty
      #
      # ============================================================

      def parse_args
        # Expect syntax: set <stat>=<value>
        name, val = cmd.args.split("=", 2)

        self.stat_name = name&.strip
        self.value = val&.strip&.to_i

        parts = self.stat_name.split(".")
        @base_stat = parts.shift&.downcase

        # Only take ONE specialty (clean + consistent with system)
        @specialty = parts.any? ? parts.first : nil
      end

      # ============================================================
      # CHECK
      #
      # Basic validation:
      # - Required arguments present
      # - Stat exists and is unambiguous
      #
      # ============================================================

      def check
        return "Usage: set <stat>=<value>" if !stat_name || value.nil?

        result = AresMUSH::Chronicles::Stats.resolve_stat(@base_stat, enactor)

        if result[:error] == :not_found
          return "Sorry, I don't know what stat you mean."
        elsif result[:error] == :ambiguous
          return "Ambiguous stat: #{@base_stat} could mean #{result[:matches].join(', ')}"
        end

        nil
      end

      # ============================================================
      # HANDLE
      #
      # Core execution:
      # 1. Resolve stat name
      # 2. Handle specialty vs base stat
      # 3. Update ChroniclesChar data
      # 4. Send success message
      #
      # ============================================================

      def handle
        result = AresMUSH::Chronicles::Stats.resolve_stat(@base_stat, enactor)
        key = result[:stat]

        if @specialty
          Chronicles::Stats.set_specialty(enactor, key, @specialty, value)

          # Normalize for display
          display = Chronicles::Stats.normalize_specialty(@specialty)

          if value > 0
            client.emit_success("Added specialty #{display} to #{key}.")
          else
            client.emit_success("Removed specialty #{display} from #{key}.")
          end

          return
        end

        cc = ChroniclesChar.for_char(enactor)
        data = cc.chronicles || {}

        data[key] = value
        cc.update(chronicles: data)

        client.emit_success("Set #{key} to #{value}.")
      end

    end
  end
end