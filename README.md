# Avram Partition Manager

A Crystal shard for managing PostgreSQL table partitions in [Avram](https://github.com/luckyframework/avram) applications.

## Installation

Add this to your application's `shard.yml`:

```yaml
dependencies:
  avram_partition_manager:
    github: your-username/avram_partition_manager
```

## Usage

### Basic Setup

Create a task to manage your partitions:

```crystal
class Db::UpdatePartitions < LuckyTask::Task
  summary "Update database partitions"

  def call
    Avram::PartitionManager.process([
      Avram::PartitionManager::Partition.new(
        "public.events",
        Avram::PartitionManager::Partition::Period::Week,
        database: AppDatabase,
        premake: 4,
        retain: 16
      )
    ])
  end
end
```

### Configuration Options

- **parent_table**: The schema and table name (e.g., `"public.events"`)
- **period**: Partition period - `Day`, `Week`, or `Month`
- **database**: Your Avram database class
- **premake**: Number of future partitions to create (default: 4)
- **retain**: Number of periods to retain (optional)
- **truncate**: Whether to truncate before dropping (default: false)
- **cascade**: Whether to use CASCADE when dropping (default: false)

### Partition Periods

- **Day**: Creates daily partitions (format: `table_p2025_06_26`)
- **Week**: Creates weekly partitions starting on Sunday
- **Month**: Creates monthly partitions starting on the 1st

### Retention Policy

When `retain` is specified, old partitions are automatically dropped:

- **Day**: Retains specified number of days
- **Week**: Retains specified number of weeks (×7 days)
- **Month**: Retains specified number of months (×30 days)

### Safety Features

- **truncate**: Optionally truncates tables before dropping to handle cascading relationships
- **cascade**: Uses CASCADE option when dropping tables to handle dependencies
- Uses `CREATE TABLE IF NOT EXISTS` and `DROP TABLE IF EXISTS` for safety

## Example

```crystal
# Create weekly partitions for an events table
# - Keep 4 weeks of future partitions ready
# - Retain 16 weeks of historical data
# - Use CASCADE when dropping old partitions
partition = Avram::PartitionManager::Partition.new(
  "public.events",
  Avram::PartitionManager::Partition::Period::Week,
  database: AppDatabase,
  premake: 4,
  retain: 16,
  cascade: true
)

Avram::PartitionManager.process([partition])
```

## Requirements

- Crystal
- PostgreSQL with native partitioning support
- Avram ORM

## Contributing

1. Fork it (<https://github.com/your-username/avram_partition_manager/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Author

Russell Smith - russ@bashme.org