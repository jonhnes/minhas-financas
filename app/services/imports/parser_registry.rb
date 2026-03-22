module Imports
  class ParserRegistry
    REGISTRY = {
      "bradesco_pdf" => Parsers::Statements::BradescoPdfParser,
      "inter_pdf" => Parsers::Statements::InterPdfParser
    }.freeze

    def self.fetch(provider_key)
      REGISTRY.fetch(provider_key.to_s) do
        raise Parsers::Statements::UnsupportedDocumentError, "Parser não suportado para #{provider_key}"
      end
    end
  end
end
