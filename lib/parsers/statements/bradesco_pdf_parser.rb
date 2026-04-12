module Parsers
  module Statements
    class BradescoPdfParser < BasePdfParser
      private

      def extract_due_date(text)
        return extract_open_statement_due_date(text) if open_statement?(text)

        extract_final_statement_due_date(text)
      end

      def extract_total_amount_cents(text)
        return extract_open_statement_total_amount_cents(text) if open_statement?(text)

        extract_final_statement_total_amount_cents(text)
      end

      def extract_items(text_pages)
        return extract_open_statement_items(text_pages) if open_statement?(text_pages.join("\n"))

        extract_final_statement_items(text_pages)
      end

      def provider_metadata
        super.merge("document_kind" => detected_document_kind)
      end

      def detected_document_kind
        @detected_document_kind ||= open_statement?(reader.pages.map(&:text).join("\n")) ? "open_statement" : "final_statement"
      end

      def extract_final_statement_due_date(text)
        match = text.match(/Total de fatura.*?Vencimento.*?R\$ ?[\d\.,]+\s+(\d{2}\/\d{2}\/\d{4})/m)
        raise UnsupportedDocumentError, "Não foi possível localizar o vencimento no PDF Bradesco" unless match

        Date.strptime(match[1], "%d/%m/%Y")
      end

      def extract_final_statement_total_amount_cents(text)
        match = text.match(/Total de fatura.*?R\$ ?([\d\.,]+)/m)
        raise UnsupportedDocumentError, "Não foi possível localizar o total da fatura Bradesco" unless match

        parse_currency_to_cents(match[1])
      end

      def extract_open_statement_due_date(text)
        match = text.match(/(\d{2}\/\d{2})\s+SALDO ANTERIOR/i)
        raise UnsupportedDocumentError, "Não foi possível localizar o vencimento no extrato em aberto Bradesco" unless match

        document_date = extract_document_date(text)
        infer_document_year_short_date(match[1], document_date)
      end

      def extract_open_statement_total_amount_cents(text)
        amounts = text.scan(/Total para:\s*.+?\s+R\$ ?([\d\.,]+)/i).flatten
        raise UnsupportedDocumentError, "Não foi possível localizar o total do extrato em aberto Bradesco" if amounts.empty?

        amounts.sum { |amount| parse_currency_to_cents(amount) }
      end

      def extract_final_statement_items(text_pages)
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

      def extract_open_statement_items(text_pages)
        items = []
        current_holder_name = nil

        text_pages.each do |page_text|
          page_text.lines.each do |line|
            stripped = line.to_s.gsub(/\s+/, " ").strip
            next if stripped.blank?

            holder_name = extract_open_statement_holder_name(stripped)
            if holder_name.present?
              current_holder_name = holder_name
              next
            end

            next if skip_open_statement_line?(stripped)

            item = parse_open_statement_line(stripped, current_holder_name)
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
        installment_metadata = bradesco_installment_metadata(description: description, occurred_on: date)

        return nil if description.blank?
        return nil unless amount.to_s.match?(/[\d\.,]+/)

        build_item(
          occurred_on: date,
          description: description,
          amount_cents: parse_currency_to_cents(amount),
          raw_holder_name: current_holder_name,
          metadata: {
            "provider_key" => "bradesco_pdf"
          }.tap do |metadata|
            metadata["installment"] = installment_metadata if installment_metadata
          end
        )
      end

      def parse_open_statement_line(line, current_holder_name)
        match = line.match(/\A(?<date>\d{2}\/\d{2})\s+(?<description>.+?)\s+\S+\s+[\d\.,]+\s+R\$ ?[\d\.,]+\s+R\$ ?(?<amount>[\d\.,]+)\z/i)
        return nil unless match

        date = parse_short_date(match[:date])
        description = match[:description].strip
        amount_cents = parse_currency_to_cents(match[:amount])
        installment_metadata = bradesco_installment_metadata(description: description, occurred_on: date)

        build_item(
          occurred_on: date,
          description: description,
          amount_cents: amount_cents,
          raw_holder_name: current_holder_name,
          metadata: {
            "provider_key" => "bradesco_pdf"
          }.tap do |metadata|
            metadata["installment"] = installment_metadata if installment_metadata
          end
        )
      end

      def open_statement?(text)
        normalized = normalize_text(text)
        normalized.include?("SITUACAO DO EXTRATO: EM ABERTO") || normalized.include?("TOTAL PARA:")
      end

      def extract_document_date(text)
        match = text.match(/Data:\s*(\d{2}\/\d{2}\/\d{4})/i)
        raise UnsupportedDocumentError, "Não foi possível localizar a data do extrato em aberto Bradesco" unless match

        Date.strptime(match[1], "%d/%m/%Y")
      end

      def infer_document_year_short_date(short_date, document_date)
        day, month = short_date.split("/").map(&:to_i)
        year = document_date.year
        year += 1 if month < document_date.month && (document_date.month - month) > 6
        year -= 1 if month > document_date.month && (month - document_date.month) > 6
        Date.new(year, month, day)
      end

      def extract_open_statement_holder_name(line)
        match = line.match(/\A(?<name>.+?)\s+-\s+VISA\b/i)
        return nil unless match

        match[:name].strip
      end

      def skip_open_statement_line?(line)
        return true if line.match?(/\ATotal para:/i)
        return true if line.match?(/\A\d{2}\/\d{2}\s+SALDO ANTERIOR/i)
        return true if line.match?(/\A(?:Aplicativo Bradesco|bradesco Data:|Situa[çc][aã]o do Extrato:)/i)
        return true if line.match?(/\A(?:\|?\s*Data|\|?\s*Hist[oó]rico|Moeda de origem|US\$|Cota[cç][aã]o US\$|R\$)\b/i)
        return true if line.match?(/\A[X\.]+\d{4}\z/i)

        false
      end
    end
  end
end
