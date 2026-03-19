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
    #
    # LEFT SIDE (before =):
    #   Flags and options:
    #     again:X        → explosion threshold (default 10)
    #     diff:X         → success threshold (default 8)
    #     exceptional:X  → exceptional success threshold (default 5)
    #     rote           → reroll failures once
    #     willpower      → +3 dice to pool
    #
    # RIGHT SIDE (after =):
    #   Dice pool expression:
    #     numbers and/or stats with + / -
    #
    # COMMENT:
    #   / anything after slash is shown in output
    #
    # ============================================================
    #
    # DESIGN GOALS:
    # - Keep dice mechanics correct (explosions, rote, chance die)
    # - Keep parsing flexible but predictable
    # - Keep output formatting separate (handled in ERB template)
    #
    # ============================================================
    #
    # SAFE TO MODIFY:
    # - Add new flags in parse_args
    # - Extend evaluate_pool_expression for new stat systems
    # - Modify ERB template for output changes
    #
    # DO NOT:
    # - Use eval() for parsing
    # - Reorder dice logic in handle without understanding consequences
    #
    # ============================================================

    class RollCmd
      include CommandHandler

      # --- Core Inputs ---
      attr_accessor :pool, :base_pool
      attr_accessor :again_threshold, :difficulty, :exceptional_threshold
      attr_accessor :flags, :comment, :unknown_stats

      # --- Roll Results ---
      attr_accessor :rolls, :rote_rolls, :rote_explosions
      attr_accessor :total_successes

      # --- Chance Die ---
      attr_accessor :chance_roll, :chance_result

      # ============================================================
      # PARSE ARGS
      #
      # Breaks the command into:
      # - flags (left side)
      # - pool math (right side)
      # - comment
      #
      # SAFE TO MODIFY:
      # - Add new flags
      # - Add new key:value options
      #
      # ============================================================

      def parse_args
        # --- Default Values ---
        self.again_threshold = 10
        self.difficulty = 8
        self.exceptional_threshold = 5
        self.flags = []
        self.pool = nil
        self.unknown_stats = []

        args = cmd.args || ""

        # Split comment from main command
        main, self.comment = args.split("/", 2)
        main ||= ""
        main = main.strip
        self.comment = self.comment&.strip

        # Split flags (left) and pool (right)
        left, right = main.split("=", 2)

        # -------------------------
        # LEFT SIDE: FLAGS
        # -------------------------
        # These control dice behavior, not math.

        option_tokens = (left || "").split

        option_tokens.each do |token|
          if token.include?(":")
            key, value = token.split(":", 2)

            case key.downcase
            when "again"
              self.again_threshold = value.to_i
            when "diff"
              self.difficulty = value.to_i
            when "exceptional"
              self.exceptional_threshold = value.to_i

            # --- ADD NEW KEY:VALUE OPTIONS HERE ---
            # when "something"
            #   self.some_variable = value.to_i

            end
          else
            # Plain flags (rote, willpower, etc.)
            self.flags << token.downcase
          end
        end

        # -------------------------
        # RIGHT SIDE: POOL + MATH
        # -------------------------
        # This evaluates expressions like:
        #   6-2+1
        #   6 - 2 + 1
        #   Dex+Firearms+2
        #
        # DO NOT replace with eval (security risk)

        if right
          self.pool = evaluate_pool_expression(right)
        else
          self.pool = evaluate_pool_expression(left)
        end

        # Store original pool BEFORE modifiers like willpower
        self.base_pool = self.pool

        # --- Apply Flag Effects That Change Dice Pool ---
        # Safe place to add dice bonuses

        if self.flags.include?("willpower") && self.pool
          self.pool += 3
        end
      end

      # ============================================================
      # CHECK
      #
      # Basic validation before rolling.
      #
      # ============================================================

      def check
        return "You must specify a dice pool." if self.pool.nil?
        return nil
      end

      # ============================================================
      # HANDLE
      #
      # Core execution:
      # 1. Chance die check
      # 2. Normal roll
      # 3. Explosions
      # 4. Rote rerolls
      #
      # DO NOT REORDER lightly.
      # Dice math depends on this order.
      #
      # ============================================================

      def handle

        # -------------------------
        # CHANCE DIE
        # -------------------------
        # Triggered when pool <= 0
        # Special rules:
        # - Only 10 succeeds
        # - 1 = dramatic failure
        # - NO explosions (CoD pg 69, seriously, the 10 doesn't reroll)

        if self.pool <= 0
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

        # -------------------------
        # NORMAL ROLL
        # -------------------------

        self.rolls = []
        self.rote_rolls = []
        self.rote_explosions = []
        self.total_successes = 0

        # --- Initial Roll ---
        first_roll = roll_dice(self.pool)

        self.rolls << first_roll
        self.total_successes += count_successes(first_roll)

        # -------------------------
        # EXPLOSIONS (X-AGAIN)
        # -------------------------
        # Rolls new dice for each die meeting the threshold.

        explosions = count_explosions(first_roll)

        while explosions > 0
          next_roll = roll_dice(explosions)
          self.rolls << next_roll
          self.total_successes += count_successes(next_roll)
          explosions = count_explosions(next_roll)
        end

        # -------------------------
        # ROTE ACTIONS
        # -------------------------
        # Reroll failures ONCE (only from initial roll)
        # Rote dice CAN explode but cannot be rerolled again.

        if self.flags.include?("rote")
          failures = first_roll.select { |r| r < self.difficulty }

          unless failures.empty?
            rote_roll = roll_dice(failures.count)
            self.rote_rolls = rote_roll
            self.total_successes += count_successes(rote_roll)

            explosions = count_explosions(rote_roll)

            while explosions > 0
              next_roll = roll_dice(explosions)
              self.rote_explosions << next_roll
              self.total_successes += count_successes(next_roll)
              explosions = count_explosions(next_roll)
            end
          end
        end

        render_output
      end

      private

      # ============================================================
      # SAFE POOL EXPRESSION PARSER
      #
      # Converts strings like:
      #   "6-2+1"
      #   "6 - 2 + 1"
      #   "Dex+Firearms+2"
      #
      # Into an integer.
      #
      # SAFE TO MODIFY:
      # - Extend for stat parsing systems
      #
      # ============================================================

      def evaluate_pool_expression(expr)
        return nil if !expr

        expr = expr.gsub(/\s+/, "")
        tokens = expr.scan(/[+-]?[^+-]+/)

        total = 0

        tokens.each do |token|
          sign = token.start_with?("-") ? -1 : 1
          value = token.gsub(/^[+-]/, "")

          if value.match?(/^\d+$/)
            total += sign * value.to_i
          else
            stat_value = lookup_stat(value)

            if stat_value.nil?
              self.unknown_stats << value
              stat_value = 0
            end

            total += sign * stat_value
          end
        end

        total
      end

      # ============================================================
      # DICE HELPERS
      # ============================================================

      def roll_dice(n)
        Array.new(n) { rand(1..10) }
      end

      def count_successes(roll)
        roll.count { |r| r >= self.difficulty }
      end

      def count_explosions(roll)
        roll.count { |r| r >= self.again_threshold }
      end

      # ============================================================
      # STAT LOOKUP
      #
      # Uses Chronicles stat system instead of FS3 or ad-hoc methods.
      # Returns nil if stat is not found so warnings can trigger.
      # ============================================================
      
      def lookup_stat(stat_name)
        return nil if !enactor

        Chronicles::Stats.get(enactor, stat_name)
      end

      # ============================================================
      # OUTPUT
      #
      # Uses ERB template.
      # Safe to modify formatting there instead of here.
      #
      # ============================================================

      def render_output
        template = File.read(File.join(Chronicles.plugin_dir, "templates", "roll.erb"))
        client.emit ERB.new(template, trim_mode: "-").result(binding)
      end

    end
  end
end