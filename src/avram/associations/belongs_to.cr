module Avram::Associations::BelongsTo
  macro belongs_to(type_declaration, foreign_key = nil)
    {% assoc_name = type_declaration.var %}

    {% if type_declaration.type.is_a?(Union) %}
      {% model = type_declaration.type.types.first %}
      {% nilable = true %}
    {% else %}
      {% model = type_declaration.type %}
      {% nilable = false %}
    {% end %}

    {% if !foreign_key %}
      {% foreign_key = "#{assoc_name}_id".id %}
    {% end %}

    column {{ foreign_key.id }} : {{ model }}::PrimaryKeyType{% if nilable %}?{% end %}

    association \
      assoc_name: :{{ assoc_name.id }},
      type: {{ model }},
      foreign_key: :{{ foreign_key.id }},
      relationship_type: :belongs_to

    define_belongs_to_private_assoc_getter({{ assoc_name }}, {{ model }}, {{ foreign_key.id }}, {{ nilable }})
    Avram::Associations.__define_public_preloaded_getters({{ assoc_name }}, {{ model }}, {{ nilable }})
    Avram::Associations.__define_preloaded_setter({{ assoc_name }}, {{ model }}, {{ nilable }})
    define_belongs_to_base_query({{ assoc_name }}, {{ model }}, {{ foreign_key.id }})
  end

  private macro define_belongs_to_private_assoc_getter(assoc_name, model, foreign_key, nilable)
    private def get_{{ assoc_name.id }}(allow_lazy : Bool = false) : {{ model }}{% if nilable %}?{% end %}
      if _{{ assoc_name }}_preloaded?
        @_preloaded_{{ assoc_name }}{% unless nilable %}.not_nil!{% end %}
      elsif lazy_load_enabled? || allow_lazy
        {{ foreign_key }}.try do |value|
          {{ model }}::BaseQuery.new.find(value)
        end
      else
        raise Avram::LazyLoadError.new {{ @type.name.stringify }}, {{ assoc_name.stringify }}
      end
    end

    def {{ assoc_name.id }}_count : Int64
      {{ foreign_key.id }}.nil? ? 0_i64 : 1_i64
    end
  end

  private macro define_belongs_to_base_query(assoc_name, model, foreign_key)
    class BaseQuery
      def self.preload_{{ assoc_name }}(record)
        preload_{{ assoc_name }}(record: record, preload_query: {{ model }}::BaseQuery.new)
      end

      def self.preload_{{ assoc_name }}(record)
        modified_query = yield {{ model }}::BaseQuery.new
        preload_{{ assoc_name }}(record: record, preload_query: modified_query)
      end

      def self.preload_{{ assoc_name }}(record, preload_query)
        preload_{{ assoc_name }}(records: [record], preload_query: preload_query).first
      end

      def self.preload_{{ assoc_name }}(records : Enumerable)
        preload_{{ assoc_name }}(records: records, preload_query: {{ model }}::BaseQuery.new)
      end

      def self.preload_{{ assoc_name }}(records : Enumerable)
        modified_query = yield {{ model }}::BaseQuery.new
        preload_{{ assoc_name }}(records: records, preload_query: modified_query)
      end

      def self.preload_{{ assoc_name }}(records : Enumerable, preload_query)
        ids = records.compact_map(&.{{ foreign_key }})
        empty_results = {} of {{ model }}::PrimaryKeyType => Array({{ model }})
        {{ assoc_name }} = ids.empty? ? empty_results  : preload_query.id.in(ids).results.group_by(&.id)
        records.map(&.dup)
          .map do |record|
            id = record.{{ foreign_key }}
            assoc = id.nil? ? nil : {{ assoc_name }}[id]?.try(&.first?)
            record.tap(&.__set_preloaded_{{ assoc_name }}(assoc))
          end
      end

      def preload_{{ assoc_name }}
        preload_{{ assoc_name }}({{ model }}::BaseQuery.new)
      end

      def preload_{{ assoc_name }}
        modified_query = yield {{ model }}::BaseQuery.new
        preload_{{ assoc_name }}(modified_query)
      end

      def preload_{{ assoc_name }}(preload_query : {{ model }}::BaseQuery)
        add_preload do |records|
          ids = records.compact_map(&.{{ foreign_key }})
          empty_results = {} of {{ model }}::PrimaryKeyType => Array({{ model }})
          {{ assoc_name }} = ids.empty? ? empty_results  : preload_query.id.in(ids).results.group_by(&.id)
          records.each do |record|
            id = record.{{ foreign_key }}
            assoc = id.nil? ? nil : {{ assoc_name }}[id]?.try(&.first?)
            record.__set_preloaded_{{ assoc_name }}(assoc)
          end
        end
        self
      end
    end
  end
end
