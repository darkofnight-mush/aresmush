module AresMUSH
  module Tinker
    class TinkerCmd
      include CommandHandler
      
      def check_can_manage
        return t('dispatcher.not_allowed') if !enactor.has_permission?("tinker")
        return nil
      end
      
      def handle
        piggies = integer_arg(cmd.args)
        if (piggies < 5)
          client.emit_ooc "#{piggies} is a small number of piggies."
        else
          client.emit_ooc "#{piggies} is a lot of piggies!"
        end
      end

    end
  end
end
