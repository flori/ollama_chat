# Module to provide duplication functionality for database models.
#
# This module allows an object to create a new instance of its own class
# with the same attributes, intentionally skipping over the primary key
# and timestamp fields to ensure a fresh record can be created.
module OllamaChat::Database::Duplicatable
  # Creates a new instance of the class with duplicated attributes.
  #
  # @return [Object] A new instance of the same class with duplicated attribute
  #   values.
  def duplicate
    klass = self.class
    attributes = columns.each_with_object({}) do |column, hash|
      [ klass.primary_key, :updated_at, :created_at ].include?(column) and next
      hash[column] = __send__(column).dup
    end
    klass.new(attributes)
  end
end
