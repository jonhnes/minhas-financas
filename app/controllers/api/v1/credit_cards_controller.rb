module Api
  module V1
    class CreditCardsController < BaseController
      before_action :set_credit_card, only: %i[show update destroy]

      def index
        authorize CreditCard
        scope = policy_scope(CreditCard).includes(:card_holders).order(active: :desc, name: :asc)
        render_collection scope, serializer: Api::V1::Serializers.method(:credit_card)
      end

      def show
        authorize @credit_card
        render json: {
          data: Api::V1::Serializers.credit_card(@credit_card).merge(
            card_holders: @credit_card.card_holders.order(:position, :name).map { |holder| Api::V1::Serializers.card_holder(holder) }
          )
        }
      end

      def create
        credit_card = current_user.credit_cards.new(credit_card_params.except(:payment_account_id))
        authorize credit_card
        credit_card.payment_account = lookup_account(credit_card_params[:payment_account_id])
        credit_card.save!

        render_resource credit_card, serializer: Api::V1::Serializers.method(:credit_card), status: :created
      end

      def update
        authorize @credit_card
        @credit_card.assign_attributes(credit_card_params.except(:payment_account_id))
        @credit_card.payment_account = lookup_account(credit_card_params[:payment_account_id])
        @credit_card.save!

        render_resource @credit_card, serializer: Api::V1::Serializers.method(:credit_card)
      end

      def destroy
        authorize @credit_card
        @credit_card.destroy!

        render json: { data: { deleted: true } }
      end

      private

      def set_credit_card
        @credit_card = policy_scope(CreditCard).find(params[:id])
      end

      def credit_card_params
        params.require(:credit_card).permit(
          :payment_account_id,
          :name,
          :brand,
          :credit_limit_cents,
          :closing_day,
          :due_day,
          :active,
          :color
        )
      end
    end
  end
end
