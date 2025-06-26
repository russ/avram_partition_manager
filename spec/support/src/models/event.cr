class Event < BaseModel
  table do
    column type : Int32
    column message : String
  end
end
