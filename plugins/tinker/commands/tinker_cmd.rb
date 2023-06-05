module AresMUSH
  module Tinker
    class TinkerCmd
      include CommandHandler
      
      def check_can_manage
        return t('dispatcher.not_allowed') if !enactor.has_permission?("tinker")
        return nil
      end
      
      def handle
        args = cmd.parse_args(ArgParser.arg1_equals_arg2)
        num_piggies = integer_arg(args.arg1)
        names = list_arg(args.arg2)
        
        client.emit "You have #{num_piggies} piggies and their names are #{names}.join(, )"
        
        if (num_piggies > names.count)
          client.emit_failure "You didn't name all your piggies!"
        end
      end

    end
  end
end
