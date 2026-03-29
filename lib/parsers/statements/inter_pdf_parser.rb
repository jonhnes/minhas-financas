module Parsers
  module Statements
    class InterPdfParser < BasePdfParser
      private

      def extract_due_date(text)
        match = text.match(/Data de Vencimento.*?(\d{2}\/\d{2}\/\d{4})/m)
        raise UnsupportedDocumentError, "Não foi possível localizar o vencimento no PDF Inter" unless match

        Date.strptime(match[1], "%d/%m/%Y")
      end

      def extract_total_amount_cents(text)
        section = text[/Total da sua fatura.*?Este [ée] o valor que voc[eê] precisa pagar nesse m[eê]s/m]
        amounts = section.to_s.scan(/R\$ ?([\d\.,]+)/).flatten
        raise UnsupportedDocumentError, "Não foi possível localizar o total da fatura Inter" if amounts.empty?

        parse_currency_to_cents(amounts.last)
      end

      def extract_items(text_pages)
        items = []
        current_card_mask = nil

        text_pages.each do |page_text|
          page_text.lines.each do |line|
            stripped = line.rstrip
            next if stripped.blank?

            columns = stripped.split(/\s{2,}/).reject(&:blank?)
            next if columns.empty?

            if columns.first.match?(/\ACART[AÃ]O /i)
              current_card_mask = columns.first.split.last
              next
            end

            next if columns.first.match?(/\ATotal CART[AÃ]O/i)

            item = parse_line(columns, current_card_mask)
            items << item if item
          end
        end

        items
      end

      def parse_line(columns, current_card_mask)
        return nil unless columns.first.match?(/\A\d{2} de /i)
        return nil if columns.length < 4

        occurred_on = parse_long_pt_date(columns[0])
        description = columns[1]
        amount = columns[-1]
        installment_metadata = inter_installment_metadata(description: description, occurred_on: occurred_on)

        build_item(
          occurred_on: occurred_on,
          description: description,
          amount_cents: parse_currency_to_cents(amount),
          metadata: {
            "provider_key" => "inter_pdf",
            "card_mask" => current_card_mask
          }.tap do |metadata|
            metadata["installment"] = installment_metadata if installment_metadata
          end
        )
      end
    end
  end
end
