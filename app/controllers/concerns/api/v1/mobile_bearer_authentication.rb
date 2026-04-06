module Api
  module V1
    module MobileBearerAuthentication
      extend ActiveSupport::Concern

      BEARER_PREFIX = "Bearer ".freeze

      private

      def bearer_token_request?
        bearer_token.present?
      end

      def bearer_token
        return @bearer_token if defined?(@bearer_token)

        header = request.authorization.to_s
        @bearer_token = header.start_with?(BEARER_PREFIX) ? header.delete_prefix(BEARER_PREFIX).presence : nil
      end

      def current_mobile_session
        return @current_mobile_session if defined?(@current_mobile_session)

        @current_mobile_session = MobileSession.authenticate_access_token(bearer_token)
      end

      def current_mobile_user
        current_mobile_session&.user
      end
    end
  end
end
