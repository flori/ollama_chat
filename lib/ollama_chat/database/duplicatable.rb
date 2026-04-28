module OllamaChat::Database::Duplicatable
  def duplicate
    klass = self.class
    attributes = columns.each_with_object({}) do |column, hash|
      [ klass.primary_key, :updated_at, :created_at ].include?(column) and next
      hash[column] = __send__(column).dup
    end
    klass.new(attributes)
  end
end
