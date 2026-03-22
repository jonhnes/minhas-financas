module Api
  module V1
    class ImportItemsController < BaseController
      before_action :set_import_item, only: :update

      def update
        authorize @import_item
        return render_locked unless @import_item.import.review_pending?

        assign_attributes
        @import_item.save!

        render json: { data: Api::V1::Serializers.import_item(@import_item) }
      end

      private

      def set_import_item
        @import_item = policy_scope(ImportItem).includes(:category, :card_holder, :import).find(params[:id])
      end

      def import_item_params
        params.require(:import_item).permit(
          :occurred_on,
          :description,
          :amount_cents,
          :card_holder_id,
          :category_id,
          :impact_mode,
          :ignored
        )
      end

      def assign_attributes
        attrs = import_item_params
        @import_item.assign_attributes(
          occurred_on: attrs[:occurred_on],
          description: attrs[:description],
          amount_cents: attrs[:amount_cents],
          impact_mode: attrs[:impact_mode],
          ignored: ActiveModel::Type::Boolean.new.cast(attrs[:ignored])
        )
        @import_item.card_holder = lookup_card_holder(attrs[:card_holder_id])
        @import_item.category = lookup_category(attrs[:category_id])
      end

      def render_locked
        render json: { errors: ["Item não pode mais ser editado"] }, status: :unprocessable_entity
      end
    end
  end
end
