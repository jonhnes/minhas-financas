module Api
  module V1
    class StatementsController < BaseController
      before_action :set_statement, only: :show

      def index
        authorize Statement
        scope = policy_scope(Statement).includes(:credit_card, :transactions).recent_first
        scope = scope.where(credit_card_id: params[:credit_card_id]) if params[:credit_card_id].present?
        render_collection scope, serializer: Api::V1::Serializers.method(:statement)
      end

      def show
        authorize @statement
        render_resource @statement, serializer: Api::V1::Serializers.method(:statement)
      end

      private

      def set_statement
        @statement = policy_scope(Statement).includes(:credit_card, :transactions).find(params[:id])
      end
    end
  end
end
