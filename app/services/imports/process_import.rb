module Imports
  class ProcessImport
    def initialize(import:)
      @import = import
    end

    def call
      import.with_lock do
        return import if import.review_pending? || import.confirmed?

        import.update!(
          status: :processing,
          processing_started_at: Time.current,
          processing_finished_at: nil,
          error_payload: {}
        )
      end

      result = parse_document

      import.transaction do
        import.import_items.delete_all

        result.fetch(:items).each do |attributes|
          import.import_items.create!(attributes)
        end

        import.update!(
          status: :review_pending,
          processing_finished_at: Time.current,
          parsed_payload: {
            "statement" => result.fetch(:statement).deep_stringify_keys,
            "summary" => result.fetch(:summary).deep_stringify_keys
          },
          raw_payload: {
            "filename" => import.source_file.filename.to_s,
            "content_type" => import.source_file.content_type,
            "byte_size" => import.source_file.byte_size,
            "page_count" => result[:page_count]
          }
        )
      end

      import
    rescue StandardError => error
      import.update!(
        status: :failed,
        processing_finished_at: Time.current,
        error_payload: {
          "message" => error.message,
          "class" => error.class.name
        }
      )
      raise
    end

    private

    attr_reader :import

    def parse_document
      parser_class = Imports::ParserRegistry.fetch(import.provider_key)
      import.source_file.open do |file|
        parser_class.new(file_path: file.path, credit_card: import.credit_card).call
      end
    end
  end
end
