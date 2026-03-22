module Api
  module V1
    module Auth
      class SessionsController < Devise::SessionsController
        respond_to :json

        private

        def respond_with(resource, _opts = {})
          render json: { data: Api::V1::Serializers.user(resource) }, status: :ok
        end

        def respond_to_on_destroy
          if current_user
            sign_out(resource_name)
          else
            sign_out_all_scopes
          end

          render json: { data: { signed_out: true } }, status: :ok
        end
      end
    end
  end
end
