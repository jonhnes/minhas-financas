module Api
  module V1
    module Pagination
      extend ActiveSupport::Concern

      private

      def paginate(scope)
        page = [params.fetch(:page, 1).to_i, 1].max
        per_page = [params.fetch(:per_page, 20).to_i, 100].min
        total_count = scope.count
        paged = scope.offset((page - 1) * per_page).limit(per_page)

        [paged, { page: page, per_page: per_page, total_count: total_count }]
      end
    end
  end
end
