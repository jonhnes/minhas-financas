module RecurringRules
  class MaterializeDueTransactionsJob < ApplicationJob
    queue_as :recurring

    def perform(reference_date = nil)
      date = reference_date.present? ? Date.parse(reference_date.to_s) : Time.zone.today
      RecurringRules::Materializer.call(date)
    end
  end
end
