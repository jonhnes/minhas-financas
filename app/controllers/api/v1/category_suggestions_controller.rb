module Api
  module V1
    class CategorySuggestionsController < BaseController
      def create
        authorize :category_suggestion, :create?

        results = CategorySuggestions::Resolver.new(user: current_user, entries: suggestion_entries).call
        render json: { data: results }
      end

      private

      def suggestion_entries
        raw_entries = params.require(:entries)
        unless raw_entries.is_a?(Array)
          raise ActionController::ParameterMissing, :entries
        end

        raw_entries.map do |entry|
          raw_entry = entry.respond_to?(:to_unsafe_h) ? entry.to_unsafe_h : entry.to_h

          ActionController::Parameters
            .new(raw_entry)
            .permit(:entry_key, :description, :canonical_merchant_name)
            .to_h
            .symbolize_keys
        end
      end
    end
  end
end
