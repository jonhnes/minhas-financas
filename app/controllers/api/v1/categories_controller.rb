module Api
  module V1
    class CategoriesController < BaseController
      before_action :set_category, only: %i[show update destroy]

      def index
        authorize Category
        scope = policy_scope(Category).order(system: :desc, parent_id: :asc, position: :asc, name: :asc)
        render_collection scope, serializer: Api::V1::Serializers.method(:category)
      end

      def show
        authorize @category
        render_resource @category, serializer: Api::V1::Serializers.method(:category)
      end

      def create
        category = current_user.categories.new(category_params.except(:parent_id))
        authorize category
        category.parent = lookup_category(category_params[:parent_id])
        category.save!

        render_resource category, serializer: Api::V1::Serializers.method(:category), status: :created
      end

      def update
        authorize @category
        @category.assign_attributes(category_params.except(:parent_id))
        @category.parent = lookup_category(category_params[:parent_id])
        @category.save!

        render_resource @category, serializer: Api::V1::Serializers.method(:category)
      end

      def destroy
        authorize @category
        @category.destroy!

        render json: { data: { deleted: true } }
      end

      private

      def set_category
        @category = policy_scope(Category).find(params[:id])
      end

      def category_params
        params.require(:category).permit(:parent_id, :name, :color, :icon, :position, :active)
      end
    end
  end
end
