module AresMUSH
  module Chronicles

    class ChroniclesChar < Ohm::Model
      include ObjectModel

      attribute :chronicles, :type => DataType::Hash, :default => {}

      reference :character, "AresMUSH::Character"

      index :character

      def self.for_char(char)
        return nil if !char

        # 🔑 Use character ID, not object
        matches = ChroniclesChar.find(character_id: char.id).to_a

        if matches.any?
          primary = matches.first

          # Clean duplicates
          if matches.count > 1
            matches[1..].each { |dup| dup.delete }
          end

          return primary
        end

        ChroniclesChar.create(character: char)
      end

    end

  end
end