module Parsers
  module Statements
    class BradescoPdfParser < BasePdfParser
      BRADESCO_MONTH_PATTERN = /JAN|FEV|MAR|ABR|MAI|JUN|JUL|AGO|SET|OUT|NOV|DEZ/i.freeze

      private

      def extract_due_date(text)
        return extract_new_statement_due_date(text) if new_statement_layout?(text)
        return extract_open_statement_due_date(text) if open_statement?(text)

        extract_final_statement_due_date(text)
      end

      def extract_total_amount_cents(text)
        return extract_new_statement_total_amount_cents(text) if new_statement_layout?(text)
        return extract_open_statement_total_amount_cents(text) if open_statement?(text)

        extract_final_statement_total_amount_cents(text)
      end

      def extract_items(text_pages)
        return extract_new_statement_items(text_pages) if new_statement_layout?(text_pages.join("\n"))
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

      def extract_new_statement_due_date(text)
        match = normalize_pdf_spaces(text).match(/Data de vencimento:\s*(\d{2}\/\d{2}\/\d{4})/i)
        raise UnsupportedDocumentError, "Não foi possível localizar o vencimento no PDF Bradesco" unless match

        Date.strptime(match[1], "%d/%m/%Y")
      end

      def extract_new_statement_total_amount_cents(text)
        match = normalize_pdf_spaces(text).match(/Total da fatura:\s*R\$\s*([\d\.,]+)/i)
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

      def extract_new_statement_items(text_pages)
        items = []
        current_holder_name = nil
        current_date = nil
        pending_day = nil
        pending_rows = []
        stop_processing = false

        text_pages.each do |page_text|
          page_text.lines.each do |line|
            stripped = normalize_new_statement_line(line)
            next if stripped.blank?

            if stop_new_statement_items_line?(stripped)
              stop_processing = true
              break
            end

            holder_name = extract_new_statement_holder_name(stripped)
            if holder_name.present?
              current_holder_name = holder_name
              current_date = nil
              pending_day = nil
              pending_rows.clear
              next
            end

            next if skip_new_statement_line?(stripped)

            if (month = extract_new_statement_month_only(stripped))
              if pending_rows.any?
                current_date = append_pending_new_statement_rows!(items, pending_rows, month)
              elsif pending_day.present?
                current_date = new_statement_date(pending_day, month)
              end

              pending_day = nil
              next
            end

            if (day = extract_new_statement_day_only(stripped))
              pending_day = day
              next
            end

            parsed = parse_new_statement_amount_line(stripped, raw_line: line)
            next unless parsed

            day = parsed[:day] || pending_day
            month = parsed[:month]

            if day.present? && month.present?
              current_date = new_statement_date(day, month)
              items << build_new_statement_item(parsed, occurred_on: current_date, raw_holder_name: current_holder_name)
              pending_day = nil
              next
            end

            if day.present?
              pending_rows << parsed.merge(day: day, raw_holder_name: current_holder_name)
              next
            end

            next unless current_date

            items << build_new_statement_item(parsed, occurred_on: current_date, raw_holder_name: current_holder_name)
          end

          break if stop_processing
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

      def parse_new_statement_amount_line(line, raw_line:)
        match = line.match(/(?<amount>-?\d[\d\.]*,\d{2})\z/)
        return nil unless match

        date_column_line = normalize_pdf_spaces(raw_line).rstrip[/\A */].size <= 5
        body = line[0...match.begin(:amount)].strip
        day = nil
        month = nil

        if date_column_line && (day_match = body.match(/\A(?<day>\d{1,2})\s+(?<rest>.+)\z/))
          parsed_day = day_match[:day].to_i
          if valid_new_statement_day?(parsed_day)
            day = parsed_day
            body = day_match[:rest].strip
          end
        end

        if date_column_line && (month_match = body.match(/\A(?<month>#{BRADESCO_MONTH_PATTERN.source})\s+(?<rest>.+)\z/i))
          month = month_match[:month]
          body = month_match[:rest].strip
        end

        description = normalize_new_statement_description(body)
        return nil if description.blank?
        return nil if skip_new_statement_description?(description)

        {
          day: day,
          month: month,
          description: description,
          amount_cents: parse_currency_to_cents(match[:amount])
        }
      end

      def build_new_statement_item(parsed, occurred_on:, raw_holder_name:)
        description = parsed.fetch(:description)
        installment_metadata = bradesco_installment_metadata(description: description, occurred_on: occurred_on)

        build_item(
          occurred_on: occurred_on,
          description: description,
          amount_cents: parsed.fetch(:amount_cents),
          raw_holder_name: raw_holder_name,
          metadata: {
            "provider_key" => "bradesco_pdf"
          }.tap do |metadata|
            metadata["installment"] = installment_metadata if installment_metadata
          end
        )
      end

      def append_pending_new_statement_rows!(items, pending_rows, month)
        last_date = nil

        pending_rows.each do |row|
          last_date = new_statement_date(row.fetch(:day), month)
          items << build_new_statement_item(row, occurred_on: last_date, raw_holder_name: row[:raw_holder_name])
        end

        pending_rows.clear
        last_date
      end

      def open_statement?(text)
        normalized = normalize_text(text)
        normalized.include?("SITUACAO DO EXTRATO: EM ABERTO") ||
          normalized.include?("TOTAL PARA:") ||
          normalized.include?("EXTRATO EM ABERTO") ||
          normalized.include?("VALORES SUJEITOS A ALTERACAO ATE O FECHAMENTO DA FATURA")
      end

      def new_statement_layout?(text)
        normalized = normalize_text(text)
        normalized.include?("DATA DE VENCIMENTO:") &&
          normalized.include?("TOTAL DA FATURA:") &&
          normalized.include?("GASTOS REFERENTES AO CARTAO")
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

      def normalize_pdf_spaces(text)
        text.to_s.tr("\u00A0", " ")
      end

      def normalize_new_statement_line(line)
        normalize_pdf_spaces(line).gsub(/\s+/, " ").strip
      end

      def normalize_new_statement_description(description)
        description.to_s.gsub(/\s+/, " ").strip
      end

      def extract_new_statement_holder_name(line)
        match = line.match(/Gastos referentes ao cart[aã]o:\s*Final\s+\d+\s*\|\s*(?<name>.+?)(?:\s+Valor da fatura:.*)?\z/i)
        return nil unless match

        match[:name].strip
      end

      def extract_new_statement_month_only(line)
        match = line.match(/\A(?<month>#{BRADESCO_MONTH_PATTERN.source})\z/i)
        match[:month] if match
      end

      def extract_new_statement_day_only(line)
        match = line.match(/\A(?<day>\d{1,2})\z/)
        return nil unless match

        day = match[:day].to_i
        day if valid_new_statement_day?(day)
      end

      def valid_new_statement_day?(day)
        day.between?(1, 31)
      end

      def new_statement_date(day, month_token)
        month = PT_BR_MONTHS.fetch(normalize_text(month_token).downcase.first(3))
        Date.new(statement_year_for_month(month), month, day.to_i)
      end

      def stop_new_statement_items_line?(line)
        line.match?(/\AData\s+Lan[cç]amentos programados\b/i) ||
          line.match?(/\AResumo das Despesas\b/i)
      end

      def skip_new_statement_line?(line)
        return true if line.match?(/\AData\s+Lan[cç]amentos\b/i)
        return true if line.match?(/\ATotal da fatura \(final\b/i)
        return true if line.match?(/\A\*?Extrato em Aberto\b/i)
        return true if line.match?(/\A(?:Fatura|Cartao selecionado|Cartão selecionado|Validade:|Forma de pagamento:|Melhor data de compra:|Valor da fatura anterior:)/i)

        false
      end

      def skip_new_statement_description?(description)
        description.match?(/\ASALDO ANTERIOR\b/i)
      end
    end
  end
end
