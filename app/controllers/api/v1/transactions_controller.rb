module Api
  module V1
    class TransactionsController < BaseController
      before_action :set_transaction, only: %i[show update destroy]

      def index
        authorize Transaction
        scope = filter_scope(policy_scope(Transaction).includes(:account, :credit_card, :card_holder, :category, :tags).chronological)
        render_collection scope, serializer: Api::V1::Serializers.method(:transaction)
      end

      def show
        authorize @transaction
        render_resource @transaction, serializer: Api::V1::Serializers.method(:transaction)
      end

      def create
        transaction = current_user.transactions.new
        authorize transaction
        assign_transaction_attributes(transaction)
        transaction.save!

        render_resource transaction, serializer: Api::V1::Serializers.method(:transaction), status: :created
      end

      def update
        authorize @transaction
        assign_transaction_attributes(@transaction)
        @transaction.save!

        render_resource @transaction, serializer: Api::V1::Serializers.method(:transaction)
      end

      def destroy
        authorize @transaction
        @transaction.destroy!

        render json: { data: { deleted: true } }
      end

      private

      def set_transaction
        @transaction = policy_scope(Transaction).includes(:tags).find(params[:id])
      end

      def transaction_params
        params.require(:transaction).permit(
          :account_id,
          :credit_card_id,
          :card_holder_id,
          :category_id,
          :transfer_account_id,
          :transaction_type,
          :impact_mode,
          :amount_cents,
          :occurred_on,
          :description,
          :notes,
          :canonical_merchant_name,
          :auto_generated,
          metadata: {},
          tag_ids: []
        )
      end

      def assign_transaction_attributes(record)
        attrs = transaction_params
        record.assign_attributes(
          transaction_type: attrs[:transaction_type],
          impact_mode: attrs[:impact_mode],
          amount_cents: attrs[:amount_cents],
          occurred_on: attrs[:occurred_on],
          description: attrs[:description],
          notes: attrs[:notes],
          canonical_merchant_name: attrs[:canonical_merchant_name],
          metadata: attrs[:metadata] || {}
        )
        record.account = lookup_account(attrs[:account_id])
        record.credit_card = lookup_credit_card(attrs[:credit_card_id])
        record.card_holder = lookup_card_holder(attrs[:card_holder_id])
        record.category = lookup_category(attrs[:category_id])
        record.transfer_account = lookup_account(attrs[:transfer_account_id])
        record.tags = current_user.tags.where(id: lookup_tag_ids(attrs[:tag_ids]))
      end

      def filter_scope(scope)
        scope = scope.where(account_id: params[:account_id]) if params[:account_id].present?
        scope = scope.where(credit_card_id: params[:credit_card_id]) if params[:credit_card_id].present?
        scope = scope.where(card_holder_id: params[:card_holder_id]) if params[:card_holder_id].present?
        scope = scope.where(category_id: params[:category_id]) if params[:category_id].present?
        scope = scope.where(statement_id: params[:statement_id]) if params[:statement_id].present?
        scope = scope.where(impact_mode: params[:impact_mode]) if params[:impact_mode].present?
        scope = scope.where(transaction_type: params[:transaction_type]) if params[:transaction_type].present?
        scope = scope.where("occurred_on >= ?", params[:occurred_from]) if params[:occurred_from].present?
        scope = scope.where("occurred_on <= ?", params[:occurred_to]) if params[:occurred_to].present?
        scope = scope.joins(:transaction_tags).where(transaction_tags: { tag_id: params[:tag_id] }) if params[:tag_id].present?

        return scope unless params[:query].present?

        query = "%#{params[:query].strip}%"
        scope.where("description ILIKE :query OR canonical_merchant_name ILIKE :query", query: query)
      end
    end
  end
end
