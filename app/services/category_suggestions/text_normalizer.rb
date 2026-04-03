module CategorySuggestions
  module TextNormalizer
    module_function

    def normalize(text)
      ActiveSupport::Inflector.transliterate(text.to_s).upcase.gsub(/\s+/, " ").strip
    end
  end
end
