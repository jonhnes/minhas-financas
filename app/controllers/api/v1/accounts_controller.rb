module Api
  module V1
    class AccountsController < BaseController
      before_action :set_account, only: %i[show update destroy]

      def index
        authorize Account
        scope = policy_scope(Account).order(active: :desc, position: :asc, name: :asc)
        render_collection scope, serializer: Api::V1::Serializers.method(:account)
      end

      def show
        authorize @account
        render_resource @account, serializer: Api::V1::Serializers.method(:account)
      end

      def create
        account = current_user.accounts.new(account_params)
        authorize account
        account.save!

        render_resource account, serializer: Api::V1::Serializers.method(:account), status: :created
      end

      def update
        authorize @account
        @account.update!(account_params)

        render_resource @account, serializer: Api::V1::Serializers.method(:account)
      end

      def destroy
        authorize @account
        @account.destroy!

        render json: { data: { deleted: true } }
      end

      private

      def set_account
        @account = policy_scope(Account).find(params[:id])
      end

      def account_params
        params.require(:account).permit(:kind, :name, :institution_name, :initial_balance_cents, :active, :color, :icon, :position)
      end
    end
  end
end
