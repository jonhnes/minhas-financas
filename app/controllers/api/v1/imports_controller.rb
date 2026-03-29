module Api
  module V1
    class ImportsController < BaseController
      before_action :set_import, only: %i[show update confirm destroy]

      def index
        authorize Import
        scope = policy_scope(Import).includes(:credit_card, :statement, :import_items).recent_first
        render_collection scope, serializer: ->(record) { Api::V1::Serializers.import(record) }
      end

      def show
        authorize @import
        render json: { data: Api::V1::Serializers.import(@import, include_items: true) }
      end

      def create
        import = current_user.imports.new(source_kind: :pdf)
        authorize import
        import.credit_card = lookup_credit_card(import_params[:credit_card_id])
        import.provider_key = import_params[:provider_key]
        import.source_file.attach(import_params[:source_file])
        import.save!

        Imports::ProcessImportJob.perform_later(import.id)

        render json: { data: Api::V1::Serializers.import(import.reload) }, status: :created
      end

      def update
        authorize @import
        return render_locked unless @import.review_pending?

        @import.update_statement_payload!(normalized_header_params)
        render json: { data: Api::V1::Serializers.import(@import.reload, include_items: true) }
      end

      def confirm
        authorize @import, :confirm?
        statement = Imports::ConfirmImport.new(import: @import).call
        render json: {
          data: Api::V1::Serializers.import(@import.reload, include_items: true),
          statement: Api::V1::Serializers.statement(statement)
        }
      rescue Imports::ConfirmImport::InvalidImportError => error
        render json: { errors: [error.message] }, status: :unprocessable_entity
      end

      def destroy
        authorize @import, :destroy?
        Imports::DestroyImport.new(import: @import).call
        head :no_content
      rescue Imports::DestroyImport::DestroyError => error
        render json: { errors: [error.message] }, status: :unprocessable_entity
      end

      private

      def set_import
        @import = policy_scope(Import).includes(:statement, import_items: %i[category card_holder]).find(params[:id])
      end

      def import_params
        params.require(:import).permit(:credit_card_id, :provider_key, :source_file)
      end

      def header_params
        params.require(:import).permit(:period_start, :period_end, :due_date, :total_amount_cents)
      end

      def normalized_header_params
        {
          period_start: Date.parse(header_params[:period_start]).iso8601,
          period_end: Date.parse(header_params[:period_end]).iso8601,
          due_date: Date.parse(header_params[:due_date]).iso8601,
          total_amount_cents: header_params[:total_amount_cents].to_i
        }
      end

      def render_locked
        render json: { errors: ["Importação não pode mais ser editada"] }, status: :unprocessable_entity
      end
    end
  end
end
