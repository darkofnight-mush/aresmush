module AresMUSH
  module Tinker
    class TinkerCmd
      include CommandHandler
      
      attr_accessor :asp, :term, :goal, :asp_list
      
      def check_can_manage
        return t('dispatcher.not_allowed') if !enactor.has_permission?("tinker")
        return nil
      end
      
      @asp_list = Array.new
      
      def handle
        args = cmd.parse_args(ArgParser.arg1_equals_arg2)
        self.term = args.arg1
        self.goal = args.arg2
        self.asp = { goal => term }
        @asp_list >> self.asp
        client.emit_success "Done!"
        
      end

    end
  end
end
