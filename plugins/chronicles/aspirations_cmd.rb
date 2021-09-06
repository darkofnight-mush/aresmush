module AresMUSH
  module Chronicles
    class SetAspCmd
      include CommandHanlder

      attr_accessor :desc :term :asp

      def handle
        args = cmd.parse_args(ArgParser.arg1_equals_arg2)
        self.desc = args.arg2
        self.term = args.arg1

        self.asp = {self.desc => self.term }

        enactor.update(aspirations: self.asp.append)

        client.emit_success "#{self.term}-term goal set!"

      end
    end
  end
end
