module Api
  module V1
    class BudgetsController < BaseController
      before_action :set_budget, only: %i[show update destroy]

      def index
        authorize Budget
        scope = policy_scope(Budget).includes(:category, :subcategory).order(:created_at)
        render json: {
          data: Reports::BudgetStatusQuery.new(user: current_user, params: params).call.map do |entry|
            Api::V1::Serializers.budget(entry[:budget], spent_cents: entry[:spent_cents]).merge(
              ratio: entry[:ratio],
              period: entry[:period]
            )
          end
        }
      end

      def show
        authorize @budget
        render_resource @budget, serializer: Api::V1::Serializers.method(:budget)
      end

      def create
        budget = current_user.budgets.new(budget_params.except(:category_id, :subcategory_id))
        authorize budget
        budget.category = lookup_budget_category(budget_params[:category_id])
        budget.subcategory = lookup_subcategory(budget_params[:subcategory_id])
        budget.save!

        render_resource budget, serializer: Api::V1::Serializers.method(:budget), status: :created
      end

      def update
        authorize @budget
        @budget.assign_attributes(budget_params.except(:category_id, :subcategory_id))
        @budget.category = lookup_budget_category(budget_params[:category_id])
        @budget.subcategory = lookup_subcategory(budget_params[:subcategory_id])
        @budget.save!

        render_resource @budget, serializer: Api::V1::Serializers.method(:budget)
      end

      def destroy
        authorize @budget
        @budget.destroy!

        render json: { data: { deleted: true } }
      end

      private

      def set_budget
        @budget = policy_scope(Budget).find(params[:id])
      end

      def budget_params
        params.require(:budget).permit(:category_id, :subcategory_id, :amount_cents, :period_type, :active)
      end
    end
  end
end
