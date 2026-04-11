class AddLastFourDigitsToCreditCards < ActiveRecord::Migration[8.0]
  def change
    add_column :credit_cards, :last_four_digits, :string
    add_index :credit_cards, [:user_id, :last_four_digits]
  end
end
