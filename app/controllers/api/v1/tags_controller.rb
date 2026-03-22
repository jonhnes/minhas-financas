module Api
  module V1
    class TagsController < BaseController
      before_action :set_tag, only: %i[show update destroy]

      def index
        authorize Tag
        scope = policy_scope(Tag).order(:name)
        render_collection scope, serializer: Api::V1::Serializers.method(:tag)
      end

      def show
        authorize @tag
        render_resource @tag, serializer: Api::V1::Serializers.method(:tag)
      end

      def create
        tag = current_user.tags.new(tag_params)
        authorize tag
        tag.save!

        render_resource tag, serializer: Api::V1::Serializers.method(:tag), status: :created
      end

      def update
        authorize @tag
        @tag.update!(tag_params)

        render_resource @tag, serializer: Api::V1::Serializers.method(:tag)
      end

      def destroy
        authorize @tag
        @tag.destroy!

        render json: { data: { deleted: true } }
      end

      private

      def set_tag
        @tag = policy_scope(Tag).find(params[:id])
      end

      def tag_params
        params.require(:tag).permit(:name, :color)
      end
    end
  end
end
