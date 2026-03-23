require "rails_helper"

RSpec.describe "API categories", type: :request do
  def auth_headers_for(user)
    sign_in user

    get "/api/v1/auth/csrf", as: :json
    token = response.parsed_body.dig("data", "csrf_token")

    {
      "ACCEPT" => "application/json",
      "CONTENT_TYPE" => "application/json",
      "X-CSRF-Token" => token
    }
  end

  it "deletes a category owned by the current user" do
    user = create(:user)
    category = create(:category, user: user)

    delete "/api/v1/categories/#{category.id}", headers: auth_headers_for(user)

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to eq("data" => { "deleted" => true })
    expect(Category.exists?(category.id)).to be(false)
  end

  it "does not allow deleting a system category" do
    user = create(:user)
    category = create(:category, :system_default)

    delete "/api/v1/categories/#{category.id}", headers: auth_headers_for(user)

    expect(response).to have_http_status(:forbidden)
    expect(response.parsed_body.fetch("errors")).not_to be_empty
    expect(Category.exists?(category.id)).to be(true)
  end

  it "nullifies the parent_id of child categories when deleting a parent category" do
    user = create(:user)
    parent = create(:category, user: user)
    child = create(:category, user: user, parent: parent)

    delete "/api/v1/categories/#{parent.id}", headers: auth_headers_for(user)

    expect(response).to have_http_status(:ok)
    expect(child.reload.parent_id).to be_nil
  end

  it "nullifies category_id on transactions when deleting a category" do
    user = create(:user)
    category = create(:category, user: user)
    account = create(:account, user: user)
    transaction = create(:transaction, user: user, account: account, category: category)

    delete "/api/v1/categories/#{category.id}", headers: auth_headers_for(user)

    expect(response).to have_http_status(:ok)
    expect(transaction.reload.category_id).to be_nil
  end

  it "returns 422 when the category is linked to a budget" do
    user = create(:user)
    category = create(:category, user: user)
    create(:budget, user: user, category: category)

    delete "/api/v1/categories/#{category.id}", headers: auth_headers_for(user)

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body.fetch("errors").first).to include("Cannot delete record")
    expect(Category.exists?(category.id)).to be(true)
  end
end
