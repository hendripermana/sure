class AddAutoRevaluationToPreciousMetals < ActiveRecord::Migration[8.1]
  def change
    change_table :precious_metals do |t|
      t.boolean :auto_revalue,  null: false, default: true
      t.string  :price_source,  limit: 50, default: "antam"
      t.string  :metal_type,    limit: 20, default: "gold"
    end

    add_index :precious_metals, :auto_revalue,
              where: "auto_revalue = true",
              name: "idx_precious_metals_auto_revalue"
  end
end
