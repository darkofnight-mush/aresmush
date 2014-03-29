module AresMUSH
  class Exit
    include ObjectModel

    key :source_id, ObjectId
    belongs_to :source, :class => Room
    
    key :dest_id, ObjectId
    belongs_to :dest, :class => Room
  end
end
