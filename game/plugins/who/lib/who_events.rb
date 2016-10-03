module AresMUSH
  module Who
    class CharConnectedEventHandler
      def on_event(event)
        count = Global.client_monitor.logged_in_clients.count
        game = Game.master
        
        if (count > game.online_record)
          game.online_record = count
          game.save
          Global.logger.info("Online Record Now: #{count}")
          Global.client_monitor.emit_all_ooc t('who.new_online_record', :count => count)
        end
      end      
    end
  end
end
