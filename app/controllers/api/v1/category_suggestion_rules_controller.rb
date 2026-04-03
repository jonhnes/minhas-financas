module Api
  module V1
    class CategorySuggestionRulesController < BaseController
      before_action :set_rule, only: %i[show update destroy]

      def index
        authorize CategorySuggestionRule
        scope = policy_scope(CategorySuggestionRule).includes(:category).order(active: :desc, position: :asc, created_at: :asc, id: :asc)
        render_collection scope, serializer: Api::V1::Serializers.method(:category_suggestion_rule)
      end

      def show
        authorize @rule
        render_resource @rule, serializer: Api::V1::Serializers.method(:category_suggestion_rule)
      end

      def create
        rule = current_user.category_suggestion_rules.new(rule_params.except(:category_id))
        authorize rule
        rule.category = lookup_category(rule_params[:category_id])
        rule.save!

        render_resource rule, serializer: Api::V1::Serializers.method(:category_suggestion_rule), status: :created
      end

      def update
        authorize @rule
        @rule.assign_attributes(rule_params.except(:category_id))
        @rule.category = lookup_category(rule_params[:category_id]) if rule_params.key?(:category_id)
        @rule.save!

        render_resource @rule, serializer: Api::V1::Serializers.method(:category_suggestion_rule)
      end

      def destroy
        authorize @rule
        @rule.destroy!

        render json: { data: { deleted: true } }
      end

      private

      def set_rule
        @rule = policy_scope(CategorySuggestionRule).includes(:category).find(params[:id])
      end

      def rule_params
        params.require(:category_suggestion_rule).permit(:category_id, :match_type, :pattern, :active, :position)
      end
    end
  end
end
