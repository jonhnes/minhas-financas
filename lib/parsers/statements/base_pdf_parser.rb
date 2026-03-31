module Parsers
  module Statements
    class UnsupportedDocumentError < StandardError; end

    class BasePdfParser
      BRADESCO_INSTALLMENT_PATTERN = /\b(?<current>\d{2})\/(?<total>\d{2})\z/.freeze
      INTER_INSTALLMENT_PATTERN = /\(PARCELA\s+(?<current>\d{2})\s+DE\s+(?<total>\d{2})\)\z/i.freeze

      PT_BR_MONTHS = {
        "jan" => 1,
        "fev" => 2,
        "mar" => 3,
        "abr" => 4,
        "mai" => 5,
        "jun" => 6,
        "jul" => 7,
        "ago" => 8,
        "set" => 9,
        "out" => 10,
        "nov" => 11,
        "dez" => 12
      }.freeze

      def initialize(file_path:, credit_card:)
        @file_path = file_path
        @credit_card = credit_card
      end

      def call
        text_pages = reader.pages.map(&:text)
        text = text_pages.join("\n")
        due_date = extract_due_date(text)
        total_amount_cents = extract_total_amount_cents(text)
        period = credit_card.statement_period_for_due_date(due_date)

        items = extract_items(text_pages).each_with_index.map do |attributes, index|
          attributes.merge(line_index: index + 1)
        end

        {
          statement: {
            period_start: period.fetch(:period_start),
            period_end: period.fetch(:period_end),
            due_date: due_date,
            total_amount_cents: total_amount_cents,
            status: "open",
            metadata: provider_metadata
          },
          summary: {
            total_items: items.count,
            ignored_items: items.count { |item| item[:ignored] },
            reviewable_items: items.count { |item| !item[:ignored] }
          },
          items: items,
          page_count: text_pages.size
        }
      end

      private

      attr_reader :credit_card, :file_path

      def reader
        @reader ||= PDF::Reader.new(file_path)
      end

      def provider_metadata
        { "provider_key" => self.class.name.demodulize.underscore.delete_suffix("_parser") }
      end

      def normalize_text(text)
        ActiveSupport::Inflector.transliterate(text.to_s).upcase.gsub(/\s+/, " ").strip
      end

      def parse_currency_to_cents(raw)
        value = raw.to_s.gsub(/[^\d,.-]/, "")
        credit = raw.to_s.include?("+") || raw.to_s.strip.end_with?("-")
        normalized = value.delete(".").tr(",", ".").delete_suffix("-")
        cents = (BigDecimal(normalized) * 100).to_i
        credit ? -cents : cents
      end

      def parse_short_date(value)
        day, month = value.split("/")
        year = statement_year_for_month(month.to_i)
        Date.new(year, month.to_i, day.to_i)
      end

      def statement_year_for_month(month)
        due_date = extract_due_date(reader.pages.first.text)
        year = due_date.year
        year -= 1 if month > due_date.month
        year
      end

      def parse_long_pt_date(value)
        match = value.match(/(\d{2}) de ([[:alpha:]]+)\.?\s+(\d{4})/i)
        raise UnsupportedDocumentError, "Data inválida: #{value}" unless match

        day = match[1].to_i
        month = PT_BR_MONTHS.fetch(normalize_text(match[2]).downcase.first(3))
        year = match[3].to_i
        Date.new(year, month, day)
      end

      def canonical_merchant_name(description)
        normalize_text(description_without_installment_marker(description))
      end

      def holder_for(raw_holder_name)
        return nil if raw_holder_name.blank?

        normalized_holder = normalize_text(raw_holder_name)
        credit_card.card_holders.detect do |holder|
          normalize_text(holder.name) == normalized_holder
        end
      end

      def build_item(occurred_on:, description:, amount_cents:, raw_holder_name: nil, metadata: {})
        installment_metadata = metadata["installment"]
        canonical_name = canonical_merchant_name(description)
        structured_installment_attributes =
          if installment_metadata.present?
            Installments::Support.build_import_item_attributes(
              credit_card_id: credit_card.id,
              canonical_merchant_name: canonical_name,
              purchase_occurred_on: installment_metadata["purchase_occurred_on"] || occurred_on,
              amount_cents: amount_cents,
              installment_number: installment_metadata["current_number"],
              installment_total: installment_metadata["total_installments"]
            )
          else
            Installments::Support.default_import_item_attributes
          end

        ignored = amount_cents.negative? || description.match?(/pagamento|pag boleto/i)
        {
          occurred_on: structured_installment_attributes[:occurred_on] || occurred_on,
          description: description.strip,
          amount_cents: amount_cents,
          transaction_type: "expense",
          impact_mode: ignored ? "informational" : "normal",
          category_id: nil,
          card_holder_id: holder_for(raw_holder_name)&.id,
          canonical_merchant_name: canonical_name,
          raw_holder_name: raw_holder_name,
          status: "pending_review",
          ignored: ignored,
          metadata: metadata
        }.merge(structured_installment_attributes.except(:occurred_on))
      end

      def description_without_installment_marker(description)
        description
          .to_s
          .gsub(INTER_INSTALLMENT_PATTERN, "")
          .gsub(/\b\d{2}\/\d{2}\b/, "")
          .gsub(/\s+/, " ")
          .strip
      end

      def bradesco_installment_metadata(description:, occurred_on:)
        build_installment_metadata(
          match: description.to_s.strip.match(BRADESCO_INSTALLMENT_PATTERN),
          occurred_on: occurred_on,
          source_format: "fractional_suffix"
        )
      end

      def inter_installment_metadata(description:, occurred_on:)
        build_installment_metadata(
          match: description.to_s.strip.match(INTER_INSTALLMENT_PATTERN),
          occurred_on: occurred_on,
          source_format: "parenthesized_parcela"
        )
      end

      def build_installment_metadata(match:, occurred_on:, source_format:)
        return nil unless match

        {
          "detected" => true,
          "current_number" => match[:current].to_i,
          "total_installments" => match[:total].to_i,
          "purchase_occurred_on" => occurred_on.iso8601,
          "source_format" => source_format
        }
      end
    end
  end
end
