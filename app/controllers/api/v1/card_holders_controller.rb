module Api
  module V1
    class CardHoldersController < BaseController
      before_action :set_credit_card, only: %i[index create]
      before_action :set_card_holder, only: %i[show update destroy]

      def index
        authorize CardHolder
        scope = @credit_card.card_holders.order(:position, :name)
        render_collection scope, serializer: Api::V1::Serializers.method(:card_holder)
      end

      def show
        authorize @card_holder
        render_resource @card_holder, serializer: Api::V1::Serializers.method(:card_holder)
      end

      def create
        card_holder = @credit_card.card_holders.new(card_holder_params)
        authorize card_holder
        card_holder.save!

        render_resource card_holder, serializer: Api::V1::Serializers.method(:card_holder), status: :created
      end

      def update
        authorize @card_holder
        @card_holder.update!(card_holder_params)

        render_resource @card_holder, serializer: Api::V1::Serializers.method(:card_holder)
      end

      def destroy
        authorize @card_holder
        @card_holder.destroy!

        render json: { data: { deleted: true } }
      end

      private

      def set_credit_card
        @credit_card = policy_scope(CreditCard).find(params[:credit_card_id])
      end

      def set_card_holder
        @card_holder = policy_scope(CardHolder).find(params[:id])
      end

      def card_holder_params
        params.require(:card_holder).permit(:name, :holder_type, :active, :position)
      end
    end
  end
end
