module Api
  module V1
    class FinancialResetsController < BaseController
      rescue_from FinancialResets::ResetTransactions::ConfirmationRequiredError, with: :render_unprocessable_entity

      def create
        authorize current_user, :update?

        result = FinancialResets::ResetTransactions.new(
          user: current_user,
          dry_run: reset_params[:dry_run],
          confirmed: reset_params[:confirmed]
        ).call

        render json: { data: result }
      end

      private

      def reset_params
        params.fetch(:reset, ActionController::Parameters.new).permit(:dry_run, :confirmed)
      end
    end
  end
end
