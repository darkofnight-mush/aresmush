module AresMUSH
  module Chronicles

    class Loader

      # ------------------------------------------------------------
      # LOAD YAML (single file)
      # ------------------------------------------------------------
      def self.load_yaml(path)
        full_path = File.join(Chronicles.plugin_dir, "config", path)
        return {} if !File.exist?(full_path)

        YAML.load_file(full_path)
      end

      # ------------------------------------------------------------
      # LOAD DIRECTORY (flat only, no recursion)
      #
      # Returns:
      # {
      #   "filename" => parsed_yaml
      # }
      #
      # Example:
      #   splats/mage/arcana.yml
      #   splats/mage/paths.yml
      #   splats/mage/mage_merits.yml
      #
      # =>
      # {
      #   "arcana" => {...},
      #   "paths" => {...},
      #   "mage_merits" => {...}
      # }
      #
      # ------------------------------------------------------------
      def self.load_dir(dir)
        base = File.join(Chronicles.plugin_dir, "config", dir)
        return {} if !Dir.exist?(base)

        Dir[File.join(base, "*.yml")].each_with_object({}) do |file, hash|
          key = File.basename(file, ".yml")
          hash[key] = YAML.load_file(file)
        end
      end

      # ------------------------------------------------------------
      # CORE STATS (unchanged)
      # ------------------------------------------------------------
      def self.stats
        @stats ||= {
          attributes: load_yaml("stats/attributes.yml"),
          skills: load_yaml("stats/skills.yml"),
          derived: load_yaml("stats/derived.yml")
        }
      end

      # ------------------------------------------------------------
      # MERITS (global, non-splat)
      # ------------------------------------------------------------
      def self.merits
        @merits ||= load_dir("merits")
      end

      # ------------------------------------------------------------
      # POWERS (global, if you still use this)
      # ------------------------------------------------------------
      def self.powers
        @powers ||= load_dir("powers")
      end

      # ------------------------------------------------------------
      # SPLAT LOADER
      #
      # Usage:
      #   Loader.splat("mage")
      #
      # Returns all YAML files inside:
      #   config/splats/mage/
      #
      # Flat structure only (by design).
      #
      # ------------------------------------------------------------
      def self.splat(name)
        key = name.to_s.downcase

        @splats ||= {}
        @splats[key] ||= load_dir(File.join("splats", key))
      end

    end
  end
end