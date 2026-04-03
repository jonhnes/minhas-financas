require "set"

module CategorySuggestions
  class Resolver
    MAX_SUGGESTIONS = 3
    RULE_CONFIDENCE = {
      "starts_with" => 0.99,
      "ends_with" => 0.97,
      "contains" => 0.94
    }.freeze

    def initialize(user:, entries:)
      @user = user
      @entries = Array(entries).map.with_index do |entry, index|
        normalize_entry(entry, fallback_index: index)
      end
    end

    def call
      return [] if entries.empty?

      load_rules
      load_history_rows

      entries.map do |entry|
        {
          entry_key: entry.fetch(:entry_key),
          suggestions: suggestions_for(entry)
        }
      end
    end

    private

    attr_reader :entries, :user

    def normalize_entry(entry, fallback_index:)
      raw_entry = entry.respond_to?(:to_h) ? entry.to_h.symbolize_keys : {}
      description = raw_entry[:description].to_s.strip
      canonical_merchant_name = raw_entry[:canonical_merchant_name].to_s.strip

      {
        entry_key: raw_entry[:entry_key].presence || fallback_index.to_s,
        description: description,
        canonical_merchant_name: canonical_merchant_name,
        normalized_texts: [
          TextNormalizer.normalize(canonical_merchant_name),
          TextNormalizer.normalize(description)
        ].reject(&:blank?).uniq
      }
    end

    def load_rules
      @rules ||= user
        .category_suggestion_rules
        .active
        .includes(:category)
        .order(:position, :created_at, :id)
        .select { |rule| valid_category?(rule.category) }
    end

    def load_history_rows
      return @history_rows if defined?(@history_rows)

      rows = user
        .transactions
        .joins(:category)
        .merge(Category.active)
        .where.not(category_id: nil)
        .where.not(transaction_type: "transfer")
        .pluck(:category_id, "categories.name", :canonical_merchant_name, :description, :occurred_on, :created_at)

      @history_rows = rows.map do |category_id, category_name, canonical_merchant_name, description, occurred_on, created_at|
        {
          category_id: category_id,
          category_name: category_name,
          occurred_on: occurred_on,
          created_at: created_at,
          fields: [
            TextNormalizer.normalize(canonical_merchant_name),
            TextNormalizer.normalize(description)
          ].reject(&:blank?).uniq
        }
      end.select { |row| row[:fields].any? }

      @exact_index = Hash.new { |hash, key| hash[key] = {} }

      @history_rows.each do |row|
        row[:fields].each do |field|
          stats = (@exact_index[field][row[:category_id]] ||= history_stats_seed(row[:category_id], row[:category_name], field))
          stats[:count] += 1
          stats[:last_seen_on] = [stats[:last_seen_on], history_last_seen_on(row)].compact.max
        end
      end
    end

    def suggestions_for(entry)
      suggestions = []
      seen_category_ids = Set.new

      [rule_suggestions_for(entry), history_suggestions_for(entry, exact: true), history_suggestions_for(entry, exact: false)].each do |candidate_set|
        candidate_set.each do |suggestion|
          next if seen_category_ids.include?(suggestion[:category_id])

          seen_category_ids << suggestion[:category_id]
          suggestions << suggestion
          break if suggestions.size >= MAX_SUGGESTIONS
        end

        break if suggestions.size >= MAX_SUGGESTIONS
      end

      suggestions
    end

    def rule_suggestions_for(entry)
      with_prioritized_text(entry) do |text|
        load_rules
          .select { |rule| rule.applies_to?(text) }
          .map do |rule|
            {
              category_id: rule.category_id,
              category_name: rule.category.name,
              source: "rule",
              match_type: rule.match_type,
              matched_text: rule.pattern,
              confidence: RULE_CONFIDENCE.fetch(rule.match_type)
            }
          end
      end
    end

    def history_suggestions_for(entry, exact:)
      with_prioritized_text(entry) do |text|
        exact ? exact_history_suggestions(text) : partial_history_suggestions(text)
      end
    end

    def exact_history_suggestions(text)
      exact_matches = @exact_index.fetch(text, {}).values

      exact_matches
        .sort_by { |match| [-match[:count], -match[:last_seen_on].jd, match[:category_name]] }
        .first(MAX_SUGGESTIONS)
        .map do |match|
          {
            category_id: match[:category_id],
            category_name: match[:category_name],
            source: "history",
            match_type: "exact",
            matched_text: match[:matched_text],
            confidence: history_confidence(exact: true, count: match[:count])
          }
        end
    end

    def partial_history_suggestions(text)
      matches_by_category = {}

      @history_rows.each do |row|
        matched_text = row[:fields].find { |field| partial_match?(query_text: text, candidate_text: field) }
        next unless matched_text

        stats = (matches_by_category[row[:category_id]] ||= history_stats_seed(row[:category_id], row[:category_name], matched_text))
        stats[:count] += 1
        stats[:last_seen_on] = [stats[:last_seen_on], history_last_seen_on(row)].compact.max
      end

      matches_by_category
        .values
        .sort_by { |match| [-match[:count], -match[:last_seen_on].jd, match[:category_name]] }
        .first(MAX_SUGGESTIONS)
        .map do |match|
          {
            category_id: match[:category_id],
            category_name: match[:category_name],
            source: "history",
            match_type: "partial",
            matched_text: match[:matched_text],
            confidence: history_confidence(exact: false, count: match[:count])
          }
        end
    end

    def history_confidence(exact:, count:)
      base = exact ? 0.82 : 0.68
      increment = exact ? 0.04 : 0.06
      ceiling = exact ? 0.94 : 0.86

      [(base + ([count - 1, 0].max * increment)), ceiling].min.round(2)
    end

    def partial_match?(query_text:, candidate_text:)
      candidate_text.include?(query_text) || query_text.include?(candidate_text)
    end

    def with_prioritized_text(entry)
      entry.fetch(:normalized_texts).each do |text|
        results = yield(text)
        return results if results.present?
      end

      []
    end

    def history_stats_seed(category_id, category_name, matched_text)
      {
        category_id: category_id,
        category_name: category_name,
        matched_text: matched_text,
        count: 0,
        last_seen_on: nil
      }
    end

    def history_last_seen_on(row)
      row[:occurred_on] || row[:created_at]&.to_date || Date.new(1970, 1, 1)
    end

    def valid_category?(category)
      category.present? && category.active?
    end
  end
end
