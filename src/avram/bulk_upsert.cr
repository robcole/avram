class Avram::BulkUpsert(T)
  alias Params = Hash(Symbol, String) | Hash(Symbol, String?) | Hash(Symbol, Nil)

  def initialize(@records : Array(Params))
  end

  def statement
    [
      "insert into #{table}(#{fields})",
      "values #{value_placeholders}",
      "ON CONFLICT DO UPDATE SET #{updates}",
      "returning #{returning}",
    ].join(" ")
  end

  private def table
    T.table_name
  end

  private def updates
    conflict_updates = T.column_names.uniq.map do |column|
      "SET #{column}=EXCLUDED.#{column}"
    end

    if T.column_names.includes?(:updated_at)
      conflict_updates.push("SET updated_at=NOW()").join(", ")
    else
      conflict_updates.join(", ")
    end
  end

  private def returning
    "id"
  end

  private def fields
    T.column_names.join(", ")
  end

  def args
    @records.map &.values
  end

  private def placeholder_values(record)
    values = record.values.map_with_index(1) do |_value, index|
      "$#{index}"
    end.join(", ")

    "(#{values})"
  end

  private def value_placeholders
    @records.map do |record|
      placeholder_values(record)
    end.join(", ")
  end
end
