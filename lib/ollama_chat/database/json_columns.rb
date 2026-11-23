module OllamaChat::Database
  # A thin wrapper over Sequel's serialization plugin for JSON columns.
  #
  # Layers a `json_column` class method on top of the `:json_go` format so
  # that a serialized column always reads back as a non-nil
  # {GenericObject} (or a caller-supplied default) and always writes a
  # {GenericObject}, never a raw hash.
  #
  # This kills the symbol/string mixed-key class of bugs that otherwise
  # surfaces as a `JSON::GeneratorError` under json 3.x: a {GenericObject}
  # can only ever hold symbol keys (it is an OpenStruct), so a bracket
  # mutation like `record.metadata['content'] = 'x'` can never fork a
  # parallel string-keyed slot.
  #
  # @example
  #   class OllamaChat::Database::Models::Prompt \
  #     < Sequel::Model(OllamaChat::DB)
  #     include OllamaChat::Database::JSONColumns
  #     plugin :serialization, :json_go, :metadata
  #     json_column :metadata, default: {}
  #   end
  #
  #   prompt.metadata.content        # => "..."
  #   prompt.metadata.content = 'x'  # in-place, symbol-keyed
  #   prompt.save
  module JSONColumns
    extend Tins::Concern

    class_methods do
      # Declares a JSON column with an optional nil-default.
      #
      # Call this AFTER `plugin :serialization, :json_go, <column>` in the
      # model body so that `super()` resolves to the plugin's reader/writer.
      # The generated reader is the single normalization point: whenever the
      # underlying value is nil it returns a *fresh*
      # `GenericObject.from_hash(default)`, so two nil-valued records never
      # share (and thus never mutate) one object. The writer coerces any
      # incoming hash/array to a `GenericObject` before handing it to the
      # plugin, so in-memory objects never hold mixed or symbol keys that
      # would break `JSON.generate`.
      #
      # @param column [Symbol] the serialized column name
      # @param default [Hash, Array, nil] value returned when the column is
      #   nil; when omitted the column is a pure pass-through (nil stays nil)
      def json_column(column, default: nil)
        plugin :serialization, :json_go, column

        define_method(column) do
          value = super()
          value.nil? && default ? GenericObject.from_hash(default) : value
        end

        define_method(:"#{column}=") do |value|
          super(value.nil? ? value : GenericObject.from_hash(value))
        end
      end
    end
  end
end
