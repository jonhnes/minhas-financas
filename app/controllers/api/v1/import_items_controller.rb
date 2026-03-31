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
          :ignored,
          :installment_enabled
        )
      end

      def assign_attributes
        attrs = import_item_params
        installment_enabled = attrs.key?(:installment_enabled) ? ActiveModel::Type::Boolean.new.cast(attrs[:installment_enabled]) : @import_item.installment_enabled?
        next_occurred_on =
          if installment_enabled && @import_item.installment_detected?
            Installments::Support.occurrence_on(
              purchase_occurred_on: @import_item.purchase_occurred_on,
              installment_number: @import_item.installment_number
            )
          elsif attrs.key?(:occurred_on)
            attrs[:occurred_on]
          else
            @import_item.occurred_on
          end

        assigned_attributes = {
          occurred_on: next_occurred_on,
          installment_enabled: installment_enabled
        }

        assigned_attributes[:description] = attrs[:description] if attrs.key?(:description)
        assigned_attributes[:amount_cents] = attrs[:amount_cents] if attrs.key?(:amount_cents)
        assigned_attributes[:impact_mode] = attrs[:impact_mode] if attrs.key?(:impact_mode)
        assigned_attributes[:ignored] = ActiveModel::Type::Boolean.new.cast(attrs[:ignored]) if attrs.key?(:ignored)

        @import_item.assign_attributes(assigned_attributes)
        @import_item.card_holder = lookup_card_holder(attrs[:card_holder_id]) if attrs.key?(:card_holder_id)
        @import_item.category = lookup_category(attrs[:category_id]) if attrs.key?(:category_id)
      end

      def render_locked
        render json: { errors: ["Item não pode mais ser editado"] }, status: :unprocessable_entity
      end
    end
  end
end
