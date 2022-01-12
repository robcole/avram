class Avram::BulkUpsert(T)
  def initialize(@records : Array(T), @column_names : Array(Symbol))
    @records = set_timestamps(records)
  end

  def statement
    [
      "INSERT INTO #{table}(#{fields})",
      "VALUES #{value_placeholders}",
      "ON CONFLICT (#{conflicts}) DO UPDATE SET #{updates}",
      "RETURNING #{returning}",
    ].join(" ")
  end

  private def conflicts
    pp @column_names.join(", ")
  end

  private def set_timestamps(collection)
    collection.map do |record|
      record.created_at.value ||= Time.utc if record.responds_to?(:created_at)
      record.updated_at.value = Time.utc if record.responds_to?(:updated_at)
      record
    end
  end

  private def table
    @records.first.table_name
  end

  private def updates
    update_keys = @records.first.insert_values.keys

    (update_keys - [:created_at]).map do |column|
      "#{column}=EXCLUDED.#{column}"
    end.join(", ")
  end

  private def returning
    T.column_names.join(", ")
  end

  private def fields
    @records.first.insert_values.keys.map do |key|
      <<-TEXT
      "#{key}"
      TEXT
    end.join(", ")
  end

  def args
    @records.flat_map do |record|
      record.insert_values.values
    end
  end

  private def value_placeholders
    values = @records.first.insert_values.map_with_index(1) do |_value, index|
      "$#{index}"
    end.join(", ")

    @records.map { |_| "(#{values})" }.join(", ")
  end
end
