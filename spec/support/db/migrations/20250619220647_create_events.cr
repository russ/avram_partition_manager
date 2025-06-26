class CreateEvents::V20250619220647 < Avram::Migrator::Migration::V1
  def migrate
    create table_for(Event) do
      add id : Int64
      add type : Int32
      add message : String
      add_timestamps

      composite_primary_key :id, :created_at
      partition_by :created_at, type: :range
    end
  end

  def rollback
    drop table_for(Event)
  end
end
