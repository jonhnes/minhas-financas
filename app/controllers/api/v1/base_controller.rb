module Api
  module V1
    class BaseController < ApplicationController
      include Api::V1::Pagination
      include Api::V1::ResourceLookup

      before_action :authenticate_api_user!
      before_action :ensure_json_request

      private

      def current_user
        current_mobile_user || super
      end

      def authenticate_api_user!
        return if current_mobile_user.present?
        return if user_signed_in?

        render json: { errors: ["Não autorizado"] }, status: :unauthorized
      end

      def ensure_json_request
        request.format = :json
      end

      def render_collection(scope, serializer:)
        paged_scope, meta = paginate(scope)
        render json: {
          data: paged_scope.map { |record| serializer.call(record) },
          meta: meta
        }
      end

      def render_resource(record, serializer:, status: :ok)
        render json: { data: serializer.call(record) }, status: status
      end
    end
  end
end
