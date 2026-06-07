class CreateGoldPrices < ActiveRecord::Migration[8.1]
  def change
    create_table :gold_prices, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.date    :date,           null: false
      t.string  :source,         null: false, limit: 50
      t.string  :metal_type,     null: false, limit: 20, default: "gold"
      t.decimal :price_per_gram, null: false, precision: 19, scale: 4
      t.decimal :buyback_price,  precision: 19, scale: 4
      t.string  :currency,       null: false, limit: 3, default: "IDR"
      t.string  :unit,           null: false, limit: 5, default: "g"
      t.boolean :provisional,    null: false, default: false
      t.jsonb   :metadata,       default: {}
      t.timestamps
    end

    add_index :gold_prices, [ :date, :source, :metal_type, :currency ],
              unique: true,
              name: "idx_gold_prices_date_source_type_currency"
    add_index :gold_prices, [ :metal_type, :date ], order: { date: :desc },
              name: "idx_gold_prices_metal_type_date_desc"
    add_index :gold_prices, :source
  end
end
