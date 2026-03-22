module Api
  module V1
    module Auth
      class CsrfTokensController < ApplicationController
        skip_before_action :verify_authenticity_token, only: :show

        def show
          render json: { data: { csrf_token: form_authenticity_token } }
        end
      end
    end
  end
end
