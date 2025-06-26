module Avram
  module PartitionManager
    Log = ::Log.for("avram_partition_manager")

    class Partition
      enum Period
        Day
        Week
        Month
      end

      getter parent_table : String
      getter database : Avram::Database.class
      getter period : Period
      getter premake : Int32
      getter retain : Int32?
      getter truncate : Bool = false
      getter cascade : Bool = false

      def initialize(
        @parent_table : String,
        @period : Period,
        @database : Avram::Database.class,
        @premake : Int32 = 4,
        @retain : Int32? = nil,
        @truncate : Bool = false,
        @cascade : Bool = false,
      )
      end
    end

    class Range
      def initialize(@partition : Partition, start : Time)
        @start = case partition.period
                 when Partition::Period::Week
                   start - (start.day_of_week.value % 7).days
                 when Partition::Period::Day
                   start.at_beginning_of_day
                 when Partition::Period::Month
                   Time.utc(start.year, start.month, 1)
                 else
                   raise "Unknown partition period"
                 end
      end

      # Drop the tables that contain data that should be expired based on the retention period
      def drop_tables
        schema, table = @partition.parent_table.split(".")
        table_suffix = retention.to_s.tr("-", "_")

        query = <<-SQL
        SELECT
          nspname, relname
        FROM
          pg_class c
        INNER JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE
          nspname = '#{schema}'
          AND relname LIKE '#{table}_p%'
          AND relkind = 'r'
          AND relname < '#{table}_p#{table_suffix}'
        ORDER BY 1, 2
        SQL

        result = @partition.database.query_all(query, as: Hash(String, String))

        result.map do |row|
          statements = [] of String
          child_table = "#{row["nspname"]}.#{row["relname"]}"

          # set a default statement
          statements << "DROP TABLE IF EXISTS #{child_table}"

          Avram::PartitionManager::Log.info { "Dropping partition table: #{child_table}" }

          # update the statement if they want the cascade or the truncate option
          if @partition.cascade
            # If desired, drops all dependent ROWS. Likely if this table is being partitioned, so will its dependents. But there are cases of self referencing tables (think parent/child relationships).
            # Leave this an option for the operator to decide. Schemas can get pretty unwieldy if you are holding data for a while.
            statements << "TRUNCATE TABLE #{child_table} CASCADE" if @partition.truncate == true
            # Drops table with dropping other constraints (views, foreign keys, etc). Note the cascade on the drop table only removes the fk constraint, not rows. So if you are not partitioning
            # dependent tables too, you can get orphaned rows (use the truncate option above to remove them), else make sure you are managing the dependent tables too.
            statements << "DROP TABLE IF EXISTS #{child_table} CASCADE"
          end

          statements.each do |statement|
            # Execute the statement to drop the table
            Avram::PartitionManager::Log.info { "Executing: #{statement}" }
            @partition.database.exec(statement)
          end

          child_table
        end
      end

      # Create tables to hold future data
      def create_tables
        schema, table = @partition.parent_table.split(".")
        start = @start
        stop = period_end(start)

        # Note that this starts in the *current* period, so we start at 0 rather
        # than 1 for the range, to be sure the current period gets a table *and*
        # we make the number of desired future tables
        (0..(@partition.premake)).map do
          child_table = "#{schema}.#{table}_p#{start.to_s("%Y_%m_%d")}"
          Avram::PartitionManager::Log.info { "Creating partition table: #{child_table}" }
          @partition.database.exec("CREATE TABLE IF NOT EXISTS #{child_table} PARTITION OF #{schema}.#{table} FOR VALUES FROM ('#{start}') TO ('#{stop}')")
          start = stop
          stop = period_end(start)
          child_table
        end
      end

      private def retention
        if retain = @partition.retain
          case @partition.period
          when Partition::Period::Month then 30 * retain
          when Partition::Period::Week  then 7 * retain
          when Partition::Period::Day   then retain
          else                               raise "Unknown partition period"
          end
        end
      end

      private def period_end(start : Time) : Time
        case @partition.period
        when Partition::Period::Week
          start + 7.days
        when Partition::Period::Day
          start + 1.day
        when Partition::Period::Month
          start + 1.month
        else
          raise "Unknown partition period"
        end
      end
    end

    def self.process(partitions, start : Time = Time.utc)
      partitions.each do |part|
        manager = Range.new(part, start)
        manager.drop_tables
        manager.create_tables
      end
    end
  end
end
