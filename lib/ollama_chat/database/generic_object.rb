require 'json'
require 'ostruct'

module OllamaChat
  module Database
    # Minimal OpenStruct-based accessor for JSON column values.
    #
    # Provides method-style read/write (obj.content), to_hash for
    # serialization, and from_hash for recursive in-memory coercion.
    # Designed for use with Sequel's serialization plugin via a custom
    # registered format — no json_class/json_create marker, no
    # create_additions support.
    #
    # @see OllamaChat::Database::JSONColumns
    class GenericObject < OpenStruct
      class << self
        # Creates a new GenericObject from a hash of attributes.
        #
        # @example
        #   go = GenericObject[hello: 'world']
        #   go.hello  # => "world"
        alias [] new

        # Recursively converts a plain Ruby data structure into a
        # tree of GenericObject instances.
        #
        # @param object [Object] the data structure to convert
        # @return [GenericObject, Array, Object]
        def from_hash(object)
          case
          when object.respond_to?(:to_hash)
            new.tap do |result|
              object.to_hash.each { |k, v| result[k] = from_hash(v) }
            end
          when object.respond_to?(:to_ary)
            object.to_ary.map { |a| from_hash(a) }
          else
            object
          end
        end

        # Parses a JSON string into a GenericObject.
        #
        # Returns an empty GenericObject for nil input or null JSON.
        #
        # @param source [String, nil] JSON string to parse
        # @return [GenericObject, Array, Object]
        def load(source)
          return new if source.nil?
          result = JSON.parse(source, object_class: self)
          result.nil? ? new : result
        end

        # Serializes an object to a JSON string.
        #
        # Strips the GenericObject wrapper via to_hash before
        # serializing; plain hashes and arrays pass through.
        #
        # @param obj [GenericObject, Hash, Array, Object]
        # @return [String]
        def dump(obj)
          JSON.dump(obj.respond_to?(:to_hash) ? obj.to_hash : obj)
        end
      end

      # Returns the attribute table as a plain Hash with symbol keys.
      #
      # @return [Hash] symbol-keyed hash of the attributes
      def to_hash
        table
      end

      delegate :empty?, to: :to_hash

      # Returns a string-keyed Hash suitable for JSON serialization.
      # No json_class marker.
      #
      # @return [Hash]
      def as_json(*)
        to_hash.transform_keys(&:to_s)
      end

      # Serializes to a JSON string.
      #
      # @return [String]
      def to_json(*a)
        as_json.to_json(*a)
      end

      # Merges another object into a new GenericObject.
      # On key conflicts, self wins.
      #
      # @param other [Object] responds to to_hash
      # @return [GenericObject]
      def |(other)
        self.class[other.to_hash.merge(to_hash)]
      end
    end
  end
end
