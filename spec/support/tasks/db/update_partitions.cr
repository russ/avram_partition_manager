class Db::UpdatePartitions < LuckyTask::Task
  summary "Update database partitions"

  def call
    Avram::PartitionManager.process(
      [
        Avram::PartitionManager::Partition.new(
          "public.events",
          Avram::PartitionManager::Partition::Period::Week,
          database: AppDatabase,
          premake: 4,
          retain: 16,
        ),
      ],
      start: Time.utc(2025, 6, 1, 0, 0, 0),
    )
  end
end
