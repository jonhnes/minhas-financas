module Api
  module V1
    class ReportsController < BaseController
      def overview
        authorize Transaction, :index?
        render json: { data: Reports::OverviewQuery.new(user: current_user, params: params).call }
      end

      def monthly_flow
        authorize Transaction, :index?
        render json: { data: Reports::MonthlyFlowQuery.new(user: current_user, params: params).call }
      end

      def category_breakdown
        authorize Transaction, :index?
        render json: { data: Reports::CategoryBreakdownQuery.new(user: current_user, params: params).call }
      end

      def budget_status
        authorize Budget, :index?
        render json: {
          data: Reports::BudgetStatusQuery.new(user: current_user, params: params).call.map do |entry|
            Api::V1::Serializers.budget(entry[:budget], spent_cents: entry[:spent_cents]).merge(
              ratio: entry[:ratio],
              period: entry[:period]
            )
          end
        }
      end

      def merchant_ranking
        authorize Transaction, :index?
        render json: { data: Reports::MerchantRankingQuery.new(user: current_user, params: params).call }
      end
    end
  end
end
