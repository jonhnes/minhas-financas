module Api
  module V1
    module Dev
      class ToolsController < BaseController
        def materialize_recurring_rules
          authorize RecurringRule, :index?

          date = params[:date].present? ? Date.parse(params[:date]) : Time.zone.today
          created = RecurringRules::Materializer.call(date, user: current_user)

          render json: {
            data: {
              date: date,
              created_count: created.size
            }
          }
        rescue Date::Error
          render json: { errors: ["Data inválida"] }, status: :unprocessable_entity
        end
      end
    end
  end
end
