class AddUiPreferencesToUsers < ActiveRecord::Migration[8.0]
  def change
    return if column_exists?(:users, :ui_preferences)

    add_column :users, :ui_preferences, :jsonb, default: {}, null: false
  end
end
