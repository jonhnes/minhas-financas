module Api
  module V1
    class RecurringRulesController < BaseController
      before_action :set_recurring_rule, only: %i[show update destroy]

      def index
        authorize RecurringRule
        scope = policy_scope(RecurringRule).includes(:category, :card_holder).order(active: :desc, next_run_on: :asc)
        render_collection scope, serializer: Api::V1::Serializers.method(:recurring_rule)
      end

      def show
        authorize @recurring_rule
        render_resource @recurring_rule, serializer: Api::V1::Serializers.method(:recurring_rule)
      end

      def create
        recurring_rule = current_user.recurring_rules.new
        authorize recurring_rule
        assign_recurring_rule_attributes(recurring_rule)
        recurring_rule.save!
        recurring_rule.schedule_next_run!

        render_resource recurring_rule, serializer: Api::V1::Serializers.method(:recurring_rule), status: :created
      end

      def update
        authorize @recurring_rule
        assign_recurring_rule_attributes(@recurring_rule)
        @recurring_rule.save!
        @recurring_rule.schedule_next_run!

        render_resource @recurring_rule, serializer: Api::V1::Serializers.method(:recurring_rule)
      end

      def destroy
        authorize @recurring_rule
        @recurring_rule.destroy!

        render json: { data: { deleted: true } }
      end

      private

      def set_recurring_rule
        @recurring_rule = policy_scope(RecurringRule).find(params[:id])
      end

      def recurring_rule_params
        params.require(:recurring_rule).permit(
          :account_id,
          :credit_card_id,
          :card_holder_id,
          :category_id,
          :frequency,
          :starts_on,
          :ends_on,
          :active,
          :transaction_type,
          :impact_mode,
          :amount_cents,
          :description,
          :notes,
          :canonical_merchant_name,
          :transfer_account_id,
          template_payload: {},
          tag_ids: []
        )
      end

      def assign_recurring_rule_attributes(record)
        attrs = recurring_rule_params
        payload = (attrs[:template_payload] || {}).to_h
        payload["tag_ids"] = lookup_tag_ids(attrs[:tag_ids])
        payload["transfer_account_id"] = attrs[:transfer_account_id] if attrs[:transfer_account_id].present?

        record.assign_attributes(
          frequency: attrs[:frequency],
          starts_on: attrs[:starts_on],
          ends_on: attrs[:ends_on],
          active: attrs.key?(:active) ? ActiveModel::Type::Boolean.new.cast(attrs[:active]) : record.active.nil? ? true : record.active,
          transaction_type: attrs[:transaction_type],
          impact_mode: attrs[:impact_mode],
          amount_cents: attrs[:amount_cents],
          description: attrs[:description],
          notes: attrs[:notes],
          canonical_merchant_name: attrs[:canonical_merchant_name],
          template_payload: payload
        )
        record.account = lookup_account(attrs[:account_id])
        record.credit_card = lookup_credit_card(attrs[:credit_card_id])
        record.card_holder = lookup_card_holder(attrs[:card_holder_id])
        record.category = lookup_category(attrs[:category_id])
      end
    end
  end
end
