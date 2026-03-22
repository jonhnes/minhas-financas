module Parsers
  module Statements
    class BradescoPdfParser < BasePdfParser
      private

      def extract_due_date(text)
        match = text.match(/Total de fatura.*?Vencimento.*?R\$ ?[\d\.,]+\s+(\d{2}\/\d{2}\/\d{4})/m)
        raise UnsupportedDocumentError, "Não foi possível localizar o vencimento no PDF Bradesco" unless match

        Date.strptime(match[1], "%d/%m/%Y")
      end

      def extract_total_amount_cents(text)
        match = text.match(/Total de fatura.*?R\$ ?([\d\.,]+)/m)
        raise UnsupportedDocumentError, "Não foi possível localizar o total da fatura Bradesco" unless match

        parse_currency_to_cents(match[1])
      end

      def extract_items(text_pages)
        items = []
        current_holder_name = nil

        text_pages.drop(1).each do |page_text|
          page_text.lines.each do |line|
            stripped = line.rstrip
            next if stripped.blank?

            columns = stripped.split(/\s{2,}/).reject(&:blank?)
            next if columns.empty?

            if columns.length >= 2 && columns[1].match?(/\ACart[aã]o \d{4}/i)
              current_holder_name = columns[0]
              next
            end

            next if columns[0].match?(/\ATotal para /i)

            item = parse_line(columns, current_holder_name)
            items << item if item
          end
        end

        items
      end

      def parse_line(columns, current_holder_name)
        amount_index = columns.rindex { |column| column.match?(/\A(?:\+\s*R\$ ?)?\d[\d\.]*,\d{2}\s*-?\z/) }
        return nil unless amount_index

        if columns[0].match?(/\A\d{2}\/\d{2}\z/)
          date = parse_short_date(columns[0])
          description_parts = columns[1...amount_index]
          amount = columns[amount_index]
        elsif columns[0].match?(/\A\d{2}\/\d{2}\s+/)
          date_part, description = columns[0].split(/\s+/, 2)
          date = parse_short_date(date_part)
          description_parts = [description, *columns[1...amount_index]]
          amount = columns[amount_index]
        else
          return nil
        end

        description_parts.pop if description_parts.size > 1 && description_parts.last.match?(/\A[[:alpha:]\s\.]+\z/)
        description = description_parts.join(" ").strip

        return nil if description.blank?
        return nil unless amount.to_s.match?(/[\d\.,]+/)

        build_item(
          occurred_on: date,
          description: description,
          amount_cents: parse_currency_to_cents(amount),
          raw_holder_name: current_holder_name,
          metadata: {
            "provider_key" => "bradesco_pdf"
          }
        )
      end
    end
  end
end
