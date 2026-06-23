class CreateMcpBrowserAuthGrants < ActiveRecord::Migration[8.0]
  def change
    create_table :mcp_browser_auth_grants do |t|
      t.references :user, null: false, foreign_key: true
      t.string :code_digest, null: false
      t.string :callback_url, null: false
      t.string :device_label
      t.datetime :expires_at, null: false
      t.datetime :used_at

      t.timestamps
    end

    add_index :mcp_browser_auth_grants, :code_digest, unique: true
    add_index :mcp_browser_auth_grants, :expires_at
    add_index :mcp_browser_auth_grants, :used_at
  end
end
