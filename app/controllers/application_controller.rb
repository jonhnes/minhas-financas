class ApplicationController < ActionController::Base
  include Pundit::Authorization
  include Api::V1::MobileBearerAuthentication

  protect_from_forgery with: :exception
  skip_forgery_protection if: :bearer_token_request?

  rescue_from ActiveRecord::RecordInvalid, with: :render_unprocessable_entity
  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
  rescue_from ActiveRecord::DeleteRestrictionError, with: :render_unprocessable_entity
  rescue_from ActionController::ParameterMissing, with: :render_bad_request
  rescue_from Pundit::NotAuthorizedError, with: :render_forbidden

  after_action :set_csrf_token_header

  private

  def render_not_found(error)
    render json: { errors: [error.message] }, status: :not_found
  end

  def render_unprocessable_entity(error)
    messages = if error.respond_to?(:record) && error.record.present?
      error.record.errors.full_messages
    else
      Array(error.message)
    end

    render json: { errors: messages }, status: :unprocessable_entity
  end

  def render_bad_request(error)
    render json: { errors: [error.message] }, status: :bad_request
  end

  def render_forbidden(error)
    render json: { errors: [error.message] }, status: :forbidden
  end

  def set_csrf_token_header
    response.set_header("X-CSRF-Token", form_authenticity_token)
  end
end
