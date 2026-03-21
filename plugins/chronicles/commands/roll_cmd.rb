module AresMUSH
  module Chronicles

    #
    # ============================================================
    # ROLL COMMAND
    #
    # Supports:
    #
    #   roll = 5
    #   roll = 6-2+1
    #   roll = Dex+Firearms+2
    #   roll again:9 diff:7 rote = Wits+Composure / shooting through fog
    #   roll 9a 6d 3e rote wp = Dex + Athletics.Climbing -1[twisted ankle] / climbing a wall
    #
    # LEFT SIDE (before =):
    #   Flags and options:
    #     again:X        → explosion threshold (default 10)
    #     diff:X         → success threshold (default 8)
    #     exceptional:X  → exceptional success threshold (default 5)
    #     rote           → reroll failures once
    #     willpower / wp → +3 dice (as modifier)
    #
    #   SHORT-HAND FLAGS:
    #     Xa   → again:X        (e.g., 9a)
    #     Xd   → diff:X         (e.g., 6d)
    #     Xe   → exceptional:X  (e.g., 3e)
    #     wp   → willpower
    #
    #   EXPLICIT FLAGS ONLY (NO PARTIAL MATCHING):
    #     diff:X, again:X, exceptional:X, exc:X
    #
    # RIGHT SIDE (after =):
    #   Dice pool expression:
    #     numbers and/or stats with + / -
    #
    #   LABELED MODIFIERS:
    #     -2[Heavy fog]
    #     +1[Aiming bonus]
    #
    #     IMPORTANT:
    #     - No spacing between the value and the label:
    #     - "-2[Heavy fog]" and "- 2[Heavy fog]" are valid
    #     - "- 2 [Heavy fog]" will NOT parse correctly
    #
    # COMMENT:
    #   / anything after slash is shown in output as a raw string. 
    #
    # ============================================================

    class RollCmd
      include CommandHandler
      
      attr_accessor :pool, :base_pool, :pool_breakdown
      attr_accessor :again_threshold, :difficulty, :exceptional_threshold
      attr_accessor :flags, :comment, :unknown_stats
      attr_accessor :modifiers

      attr_accessor :rolls, :rote_rolls, :rote_explosions
      attr_accessor :total_successes

      attr_accessor :chance_roll, :chance_result

      # --- DEBUG TOGGLE ---
      def debug(msg)
        return unless self.flags&.include?("debug")
        client.emit_ooc("DEBUG: #{msg}")
      end

      def parse_args
        self.again_threshold = 10
        self.difficulty = 8
        self.exceptional_threshold = 5
        self.flags = []
        self.pool = nil
        self.unknown_stats = []
        self.modifiers = []

        args = cmd.args || ""
        debug("RAW INPUT: #{args}")

        main, self.comment = args.split("/", 2)
        main ||= ""
        main = main.strip
        self.comment = self.comment&.strip

        debug("MAIN: #{main}")
        debug("COMMENT: #{self.comment}")

        left, right = main.split("=", 2)

        debug("LEFT: #{left}")
        debug("RIGHT: #{right}")

        option_tokens = (left || "").split

        debug("OPTION TOKENS: #{option_tokens}")

        option_tokens.each do |token|
          original = token
          token = token.downcase

          if token.match(/^(\d+)a$/)
            token = "again:#{$1}"
          elsif token.match(/^(\d+)d$/)
            token = "diff:#{$1}"
          elsif token.match(/^(\d+)e$/)
            token = "exceptional:#{$1}"
          elsif token == "wp"
            token = "willpower"
          end

          debug("TOKEN: #{original} → #{token}")

          if token.include?(":")
            key, value = token.split(":", 2)
            v = value.to_i

            debug("PARSED FLAG: #{key}:#{v}")

            if v <= 0
              debug("⚠️ SKIPPED FLAG (value <= 0): #{token}")
              next
            end

            case key
            when "again"
              self.again_threshold = v
            when "diff"
              self.difficulty = v
            when "exceptional", "exc"
              self.exceptional_threshold = v
            else
              debug("⚠️ UNKNOWN FLAG KEY: #{key}")
            end
          else
            self.flags << token
          end
        end

        debug("FLAGS: #{self.flags}")
        debug("AGAIN: #{self.again_threshold}, DIFF: #{self.difficulty}, EXC: #{self.exceptional_threshold}")

        if self.flags.include?("willpower")
          self.modifiers << { value: 3, label: "Willpower" }
          debug("APPLIED WILLPOWER (PRE-EVAL)")
        end

        if right
          self.pool = evaluate_pool_expression(right)
        else
          self.pool = evaluate_pool_expression(left)
        end

        self.base_pool = self.pool

        debug("POOL AFTER EXPRESSION: #{self.pool}")
        debug("MODIFIERS: #{self.modifiers}")
      end

      def check
        return "You must specify a dice pool." if self.pool.nil?
        return nil
      end

      def handle
        debug("ENTER HANDLE WITH POOL: #{self.pool}")

        if self.pool <= 0
          debug("CHANCE DIE TRIGGERED")

          self.chance_roll = rand(1..10)

          if self.chance_roll == 10
            self.chance_result = :success
          elsif self.chance_roll == 1
            self.chance_result = :dramatic_failure
          else
            self.chance_result = :failure
          end

          render_output
          return
        end

        self.rolls = []
        self.rote_rolls = []
        self.rote_explosions = []
        self.total_successes = 0

        first_roll = roll_dice(self.pool)
        debug("FIRST ROLL: #{first_roll}")

        self.rolls << first_roll
        self.total_successes += count_successes(first_roll)

        explosions = count_explosions(first_roll)
        debug("INITIAL EXPLOSIONS: #{explosions}")

        explosion_guard = 0

        while explosions > 0 && explosion_guard < 50
          explosion_guard += 1
          debug("EXPLOSION LOOP #{explosion_guard}, COUNT: #{explosions}")

          next_roll = roll_dice(explosions)
          self.rolls << next_roll
          self.total_successes += count_successes(next_roll)
          explosions = count_explosions(next_roll)
        end

        if explosion_guard >= 50
          debug("⚠️ EXPLOSION GUARD TRIPPED")
        end

        if self.flags.include?("rote")
          failures = first_roll.select { |r| r < self.difficulty }
          debug("ROTE FAILURES: #{failures}")

          unless failures.empty?
            rote_roll = roll_dice(failures.count)
            self.rote_rolls = rote_roll
            self.total_successes += count_successes(rote_roll)

            explosions = count_explosions(rote_roll)
            explosion_guard = 0

            while explosions > 0 && explosion_guard < 50
              explosion_guard += 1
              debug("ROTE EXPLOSION LOOP #{explosion_guard}")

              next_roll = roll_dice(explosions)
              self.rote_explosions << next_roll
              self.total_successes += count_successes(next_roll)
              explosions = count_explosions(next_roll)
            end
          end
        end

        debug("TOTAL SUCCESSES: #{self.total_successes}")

        render_output
      end

      private

      def evaluate_pool_expression(expr)
        return nil if !expr

        debug("EVAL START: #{expr}")

        protected = ""
        inside = false

        expr.each_char do |c|
          if c == "["
            inside = true
          elsif c == "]"
            inside = false
          elsif inside && c == " "
            c = "__SPACE__"
          end
          protected << c
        end

        expr = protected.gsub(/\s+/, "").gsub("__SPACE__", " ")
        debug("CLEANED EXPR: #{expr}")

        tokens = expr.scan(/[+-]?[^+-]+/)
        debug("TOKENS: #{tokens}")

        total = 0
        self.pool_breakdown = []

        tokens.each do |token|
          debug("PROCESS TOKEN: #{token}")

          explicit = token.start_with?("+") || token.start_with?("-")
          sign = token.start_with?("-") ? -1 : 1
          value = token.gsub(/^[+-]/, "")

          parts = value.split(".")
          base = parts.shift
          specialties = parts

          debug("BASE: #{base}, SPECS: #{specialties}")

          if base.match?(/^\d+(\[.*\])?$/)
            match = base.match(/^(\d+)(?:\[(.*)\])?$/)
            num = match[1].to_i
            label = match[2]

            debug("NUMBER: #{num}, LABEL: #{label}")

            if label
              self.modifiers << {
                value: sign * num,
                label: label.strip
              }
            else
              self.modifiers << {
                value: sign * num,
                label: nil
              }
            end

          else
            result = Chronicles::Stats.resolve_stat(base, enactor)
            debug("STAT RESOLVE: #{base} → #{result}")

            if result[:error]
              debug("⚠️ UNKNOWN STAT: #{base}")
              self.unknown_stats << base
              stat_value = 0
              key = base
            else
              key = result[:stat].to_s.strip.downcase
              stat_value = Chronicles::Stats.get(enactor, key) || 0

              debug("STAT VALUE: #{key} = #{stat_value}")

              bonus = 0
              resolved_specialties = []

              specialties.each do |spec|
                resolved = Chronicles::Stats.resolve_specialty(enactor, key, spec)
                debug("SPECIALTY: #{spec} → #{resolved}")

                if resolved.nil?
                  debug("⚠️ UNKNOWN SPECIALTY: #{key}.#{spec}")
                  self.unknown_stats << "#{key}.#{spec}"
                  self.modifiers << { value: 0, label: "Unknown Specialty (#{key.capitalize}: #{spec})" }
                elsif resolved.is_a?(Hash) && resolved[:error] == :ambiguous
                  client.emit_ooc("Ambiguous specialty '#{spec}': #{resolved[:matches].join(', ')}")
                else
                  if Chronicles::Stats.specialty_active?(enactor, key, resolved)
                    if (Chronicles::Stats.get(enactor, key) || 0) > 0
                      resolved_specialties << resolved
                      bonus += 1
                    end
                  end
                end
              end

              stat_value += bonus

              self.pool_breakdown << {
                name: key,
                value: stat_value,
                type: :stat,
                sign: sign,
                specialties: resolved_specialties,
                explicit: explicit
              }
            end

            total += sign * stat_value
          end
        end

        modifier_total = self.modifiers.map { |m| m[:value] }.sum
        debug("TOTAL BEFORE MODS: #{total}")
        debug("MODIFIER TOTAL: #{modifier_total}")

        final = total + modifier_total
        debug("FINAL POOL: #{final}")

        final
      end

      def roll_dice(n)
        debug("ROLLING #{n} DICE")
        Array.new(n) { rand(1..10) }
      end

      def count_successes(roll)
        roll.count { |r| r >= self.difficulty }
      end

      def count_explosions(roll)
        roll.count { |r| r >= self.again_threshold }
      end

      def render_output
        debug("RENDER OUTPUT")
        template = File.read(File.join(Chronicles.plugin_dir, "templates", "roll.erb"))
        client.emit ERB.new(template, trim_mode: "-").result(binding)
      end

    end
  end
end