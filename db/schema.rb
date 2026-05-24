# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_05_24_122331) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  # Custom types defined in this database.
  # Note that some types may not work with other database engines. Be careful if changing database.
  create_enum "account_status", ["ok", "syncing", "error"]

  create_table "account_providers", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.datetime "created_at", null: false
    t.uuid "provider_id", null: false
    t.string "provider_type", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "provider_type"], name: "index_account_providers_on_account_and_provider_type", unique: true
    t.index ["account_id", "provider_type"], name: "index_account_providers_on_account_id_and_provider_type", unique: true
    t.index ["provider_type", "provider_id"], name: "index_account_providers_on_provider_type_and_provider_id", unique: true
  end

  create_table "accounts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.text "access_token_encrypted"
    t.uuid "accountable_id"
    t.string "accountable_type"
    t.decimal "balance", precision: 19, scale: 4
    t.integer "balances_count", default: 0, null: false
    t.decimal "cash_balance", precision: 19, scale: 4, default: "0.0"
    t.virtual "classification", type: :string, as: "\nCASE\n    WHEN ((accountable_type)::text = ANY (ARRAY[('Loan'::character varying)::text, ('CreditCard'::character varying)::text, ('OtherLiability'::character varying)::text])) THEN 'liability'::text\n    ELSE 'asset'::text\nEND", stored: true
    t.datetime "created_at", null: false
    t.string "currency"
    t.integer "entries_count", default: 0, null: false
    t.string "external_id"
    t.uuid "family_id", null: false
    t.uuid "import_id"
    t.string "institution_domain"
    t.string "institution_name"
    t.jsonb "locked_attributes", default: {}
    t.string "name"
    t.text "notes"
    t.uuid "plaid_account_id"
    t.string "provider"
    t.uuid "provider_id"
    t.uuid "simplefin_account_id"
    t.string "status", default: "active"
    t.string "subtype"
    t.datetime "updated_at", null: false
    t.index ["accountable_id", "accountable_type"], name: "index_accounts_on_accountable_id_and_accountable_type"
    t.index ["accountable_type"], name: "index_accounts_on_accountable_type"
    t.index ["currency"], name: "index_accounts_on_currency"
    t.index ["external_id"], name: "index_accounts_on_external_id"
    t.index ["family_id", "accountable_type"], name: "index_accounts_on_family_id_and_accountable_type"
    t.index ["family_id", "id"], name: "index_accounts_on_family_id_and_id"
    t.index ["family_id", "status"], name: "index_accounts_on_family_id_and_status"
    t.index ["family_id"], name: "index_accounts_on_family_id"
    t.index ["import_id"], name: "index_accounts_on_import_id"
    t.index ["plaid_account_id"], name: "index_accounts_on_plaid_account_id"
    t.index ["provider"], name: "index_accounts_on_provider"
    t.index ["provider_id"], name: "index_accounts_on_provider_id"
    t.index ["simplefin_account_id"], name: "index_accounts_on_simplefin_account_id"
    t.index ["status"], name: "index_accounts_on_status"
  end

  create_table "active_storage_attachments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.uuid "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "addresses", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "addressable_id"
    t.string "addressable_type"
    t.string "country"
    t.string "county"
    t.datetime "created_at", null: false
    t.string "line1"
    t.string "line2"
    t.string "locality"
    t.integer "postal_code"
    t.string "region"
    t.datetime "updated_at", null: false
    t.index ["addressable_type", "addressable_id"], name: "index_addresses_on_addressable"
  end

  create_table "api_keys", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "display_key", null: false
    t.datetime "expires_at"
    t.datetime "last_used_at"
    t.string "name"
    t.datetime "revoked_at"
    t.json "scopes"
    t.string "source", default: "web"
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["display_key"], name: "index_api_keys_on_display_key", unique: true
    t.index ["revoked_at"], name: "index_api_keys_on_revoked_at"
    t.index ["user_id", "source"], name: "index_api_keys_on_user_id_and_source"
    t.index ["user_id"], name: "index_api_keys_on_user_id"
  end

  create_table "audit_logs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "auditable_id", null: false
    t.string "auditable_type", null: false
    t.jsonb "changeset", default: {}, null: false
    t.datetime "created_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.string "event", default: "update", null: false
    t.string "ip_address"
    t.uuid "user_id"
    t.index ["auditable_type", "auditable_id"], name: "index_audit_logs_on_auditable_type_and_auditable_id"
    t.index ["event"], name: "index_audit_logs_on_event"
    t.index ["user_id"], name: "index_audit_logs_on_user_id"
  end

  create_table "balances", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.decimal "balance", precision: 19, scale: 4, null: false
    t.decimal "cash_adjustments", precision: 19, scale: 4, default: "0.0", null: false
    t.decimal "cash_balance", precision: 19, scale: 4, default: "0.0"
    t.decimal "cash_inflows", precision: 19, scale: 4, default: "0.0", null: false
    t.decimal "cash_outflows", precision: 19, scale: 4, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.string "currency", default: "USD", null: false
    t.date "date", null: false
    t.virtual "end_balance", type: :decimal, precision: 19, scale: 4, as: "(((start_cash_balance + ((cash_inflows - cash_outflows) * (flows_factor)::numeric)) + cash_adjustments) + (((start_non_cash_balance + ((non_cash_inflows - non_cash_outflows) * (flows_factor)::numeric)) + net_market_flows) + non_cash_adjustments))", stored: true
    t.virtual "end_cash_balance", type: :decimal, precision: 19, scale: 4, as: "((start_cash_balance + ((cash_inflows - cash_outflows) * (flows_factor)::numeric)) + cash_adjustments)", stored: true
    t.virtual "end_non_cash_balance", type: :decimal, precision: 19, scale: 4, as: "(((start_non_cash_balance + ((non_cash_inflows - non_cash_outflows) * (flows_factor)::numeric)) + net_market_flows) + non_cash_adjustments)", stored: true
    t.integer "flows_factor", default: 1, null: false
    t.decimal "net_market_flows", precision: 19, scale: 4, default: "0.0", null: false
    t.decimal "non_cash_adjustments", precision: 19, scale: 4, default: "0.0", null: false
    t.decimal "non_cash_inflows", precision: 19, scale: 4, default: "0.0", null: false
    t.decimal "non_cash_outflows", precision: 19, scale: 4, default: "0.0", null: false
    t.virtual "start_balance", type: :decimal, precision: 19, scale: 4, as: "(start_cash_balance + start_non_cash_balance)", stored: true
    t.decimal "start_cash_balance", precision: 19, scale: 4, default: "0.0", null: false
    t.decimal "start_non_cash_balance", precision: 19, scale: 4, default: "0.0", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "currency", "date"], name: "index_balances_on_account_currency_date_desc", order: { date: :desc }
    t.index ["account_id", "date", "currency"], name: "index_account_balances_on_account_id_date_currency_unique", unique: true
    t.index ["account_id", "date"], name: "index_balances_on_account_id_and_date", order: { date: :desc }
    t.index ["account_id"], name: "index_balances_on_account_id"
  end

  create_table "budget_categories", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "budget_id", null: false
    t.decimal "budgeted_spending", precision: 19, scale: 4, null: false
    t.uuid "category_id", null: false
    t.datetime "created_at", null: false
    t.string "currency", null: false
    t.datetime "updated_at", null: false
    t.index ["budget_id", "category_id"], name: "index_budget_categories_on_budget_id_and_category_id", unique: true
    t.index ["budget_id"], name: "index_budget_categories_on_budget_id"
    t.index ["category_id"], name: "index_budget_categories_on_category_id"
  end

  create_table "budgets", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.decimal "budgeted_spending", precision: 19, scale: 4
    t.datetime "created_at", null: false
    t.string "currency", null: false
    t.date "end_date", null: false
    t.decimal "expected_income", precision: 19, scale: 4
    t.uuid "family_id", null: false
    t.date "start_date", null: false
    t.datetime "updated_at", null: false
    t.index ["family_id", "start_date", "end_date"], name: "index_budgets_on_family_id_and_start_date_and_end_date", unique: true
    t.index ["family_id"], name: "index_budgets_on_family_id"
  end

  create_table "categories", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "classification", default: "expense", null: false
    t.string "color", default: "#6172F3", null: false
    t.datetime "created_at", null: false
    t.uuid "family_id", null: false
    t.string "key"
    t.string "lucide_icon", default: "shapes", null: false
    t.string "name", null: false
    t.uuid "parent_id"
    t.datetime "updated_at", null: false
    t.index ["family_id", "key"], name: "idx_categories_family_key", unique: true, where: "(key IS NOT NULL)"
    t.index ["family_id"], name: "index_categories_on_family_id"
    t.index ["parent_id"], name: "index_categories_on_parent_id"
  end

  create_table "chats", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "error"
    t.string "instructions"
    t.string "latest_assistant_response_id"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["latest_assistant_response_id"], name: "index_chats_on_latest_assistant_response_id"
    t.index ["user_id"], name: "index_chats_on_user_id"
  end

  create_table "credit_cards", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.decimal "annual_fee", precision: 10, scale: 2
    t.decimal "apr", precision: 10, scale: 2
    t.decimal "available_credit", precision: 10, scale: 2
    t.string "card_type"
    t.string "compliance_type", default: "conventional"
    t.datetime "created_at", null: false
    t.date "expiration_date"
    t.string "fee_structure"
    t.boolean "interest_free_period", default: false
    t.jsonb "locked_attributes", default: {}
    t.decimal "minimum_payment", precision: 10, scale: 2
    t.string "subtype"
    t.datetime "updated_at", null: false
    t.index ["compliance_type"], name: "index_credit_cards_on_compliance_type"
  end

  create_table "cryptos", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "locked_attributes", default: {}
    t.string "subtype"
    t.datetime "updated_at", null: false
  end

  create_table "data_enrichments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "attribute_name"
    t.datetime "created_at", null: false
    t.uuid "enrichable_id", null: false
    t.string "enrichable_type", null: false
    t.jsonb "metadata"
    t.string "source"
    t.datetime "updated_at", null: false
    t.jsonb "value"
    t.index ["enrichable_id", "enrichable_type", "source", "attribute_name"], name: "idx_on_enrichable_id_enrichable_type_source_attribu_5be5f63e08", unique: true
    t.index ["enrichable_type", "enrichable_id"], name: "index_data_enrichments_on_enrichable"
  end

  create_table "depositories", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "locked_attributes", default: {}
    t.string "subtype"
    t.datetime "updated_at", null: false
  end

  create_table "entries", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.decimal "amount", precision: 19, scale: 4, null: false
    t.datetime "created_at", null: false
    t.string "currency"
    t.date "date"
    t.uuid "entryable_id"
    t.string "entryable_type"
    t.boolean "excluded", default: false
    t.string "external_id"
    t.uuid "import_id"
    t.jsonb "locked_attributes", default: {}
    t.string "name", null: false
    t.text "notes"
    t.uuid "parent_entry_id"
    t.string "plaid_id"
    t.string "source"
    t.datetime "updated_at", null: false
    t.index "lower((name)::text)", name: "index_entries_on_lower_name"
    t.index ["account_id", "date"], name: "index_entries_on_account_id_and_date"
    t.index ["account_id", "source", "external_id"], name: "index_entries_on_account_source_and_external_id", unique: true, where: "((external_id IS NOT NULL) AND (source IS NOT NULL))"
    t.index ["account_id"], name: "index_entries_on_account_id"
    t.index ["date"], name: "index_entries_on_date"
    t.index ["entryable_id"], name: "index_entries_on_entryable_id"
    t.index ["entryable_type"], name: "index_entries_on_entryable_type"
    t.index ["import_id"], name: "index_entries_on_import_id"
    t.index ["parent_entry_id"], name: "index_entries_on_parent_entry_id"
    t.index ["plaid_id"], name: "index_entries_on_plaid_id"
  end

  create_table "eval_datasets", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.string "description"
    t.string "eval_type", null: false
    t.jsonb "metadata", default: {}
    t.string "name", null: false
    t.integer "sample_count", default: 0
    t.datetime "updated_at", null: false
    t.string "version", default: "1.0", null: false
    t.index ["eval_type", "active"], name: "index_eval_datasets_on_eval_type_and_active"
    t.index ["name"], name: "index_eval_datasets_on_name", unique: true
  end

  create_table "eval_results", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.jsonb "actual_output", null: false
    t.boolean "alternative_match", default: false
    t.integer "completion_tokens"
    t.boolean "correct", null: false
    t.decimal "cost", precision: 10, scale: 6
    t.datetime "created_at", null: false
    t.uuid "eval_run_id", null: false
    t.uuid "eval_sample_id", null: false
    t.boolean "exact_match", default: false
    t.float "fuzzy_score"
    t.boolean "hierarchical_match", default: false
    t.integer "latency_ms"
    t.jsonb "metadata", default: {}
    t.boolean "null_expected", default: false
    t.boolean "null_returned", default: false
    t.integer "prompt_tokens"
    t.datetime "updated_at", null: false
    t.index ["eval_run_id", "correct"], name: "index_eval_results_on_eval_run_id_and_correct"
    t.index ["eval_run_id"], name: "index_eval_results_on_eval_run_id"
    t.index ["eval_sample_id"], name: "index_eval_results_on_eval_sample_id"
  end

  create_table "eval_runs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.text "error_message"
    t.uuid "eval_dataset_id", null: false
    t.jsonb "metrics", default: {}
    t.string "model", null: false
    t.string "name"
    t.string "provider", null: false
    t.jsonb "provider_config", default: {}
    t.datetime "started_at"
    t.string "status", default: "pending", null: false
    t.integer "total_completion_tokens", default: 0
    t.decimal "total_cost", precision: 10, scale: 6, default: "0.0"
    t.integer "total_prompt_tokens", default: 0
    t.datetime "updated_at", null: false
    t.index ["eval_dataset_id", "model"], name: "index_eval_runs_on_eval_dataset_id_and_model"
    t.index ["eval_dataset_id"], name: "index_eval_runs_on_eval_dataset_id"
    t.index ["provider", "model"], name: "index_eval_runs_on_provider_and_model"
    t.index ["status"], name: "index_eval_runs_on_status"
  end

  create_table "eval_samples", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.jsonb "context_data", default: {}
    t.datetime "created_at", null: false
    t.string "difficulty", default: "medium"
    t.uuid "eval_dataset_id", null: false
    t.jsonb "expected_output", null: false
    t.jsonb "input_data", null: false
    t.jsonb "metadata", default: {}
    t.string "tags", default: [], array: true
    t.datetime "updated_at", null: false
    t.index ["eval_dataset_id", "difficulty"], name: "index_eval_samples_on_eval_dataset_id_and_difficulty"
    t.index ["eval_dataset_id"], name: "index_eval_samples_on_eval_dataset_id"
    t.index ["tags"], name: "index_eval_samples_on_tags", using: :gin
  end

  create_table "exchange_rate_histories", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "currency_code", limit: 3, null: false
    t.date "effective_date", null: false
    t.decimal "rate_to_idr", precision: 18, scale: 6, null: false
    t.datetime "updated_at", null: false
    t.index ["currency_code", "effective_date"], name: "idx_exrate_hist_currency_date", unique: true
  end

  create_table "exchange_rates", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "date", null: false
    t.string "from_currency", null: false
    t.decimal "rate", null: false
    t.string "to_currency", null: false
    t.datetime "updated_at", null: false
    t.index ["from_currency", "to_currency", "date"], name: "index_exchange_rates_on_base_converted_date_unique", unique: true
    t.index ["from_currency"], name: "index_exchange_rates_on_from_currency"
    t.index ["to_currency"], name: "index_exchange_rates_on_to_currency"
  end

  create_table "families", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.boolean "auto_sync_on_login", default: true, null: false
    t.string "country", default: "US"
    t.datetime "created_at", null: false
    t.string "currency", default: "USD"
    t.boolean "data_enrichment_enabled", default: false
    t.string "date_format", default: "%m-%d-%Y"
    t.boolean "early_access", default: false
    t.datetime "latest_sync_activity_at", default: -> { "CURRENT_TIMESTAMP" }
    t.datetime "latest_sync_completed_at", default: -> { "CURRENT_TIMESTAMP" }
    t.string "locale", default: "en"
    t.string "name"
    t.string "stripe_customer_id"
    t.string "timezone"
    t.datetime "updated_at", null: false
    t.index ["stripe_customer_id"], name: "index_families_on_stripe_customer_id"
  end

  create_table "family_exports", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "family_id", null: false
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["family_id"], name: "index_family_exports_on_family_id"
  end

  create_table "holdings", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.uuid "account_provider_id"
    t.decimal "amount", precision: 19, scale: 4, null: false
    t.decimal "cost_basis", precision: 19, scale: 4
    t.datetime "created_at", null: false
    t.string "currency", null: false
    t.date "date", null: false
    t.string "external_id"
    t.decimal "price", precision: 19, scale: 4, null: false
    t.decimal "qty", precision: 19, scale: 4, null: false
    t.uuid "security_id", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "external_id"], name: "idx_holdings_on_account_id_external_id_unique", unique: true, where: "(external_id IS NOT NULL)"
    t.index ["account_id", "security_id", "date", "currency"], name: "idx_on_account_id_security_id_date_currency_5323e39f8b", unique: true
    t.index ["account_id"], name: "index_holdings_on_account_id"
    t.index ["account_provider_id"], name: "index_holdings_on_account_provider_id"
    t.index ["security_id"], name: "index_holdings_on_security_id"
  end

  create_table "impersonation_session_logs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "action"
    t.string "controller"
    t.datetime "created_at", null: false
    t.uuid "impersonation_session_id", null: false
    t.string "ip_address"
    t.string "method"
    t.text "path"
    t.datetime "updated_at", null: false
    t.text "user_agent"
    t.index ["impersonation_session_id"], name: "index_impersonation_session_logs_on_impersonation_session_id"
  end

  create_table "impersonation_sessions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "impersonated_id", null: false
    t.uuid "impersonator_id", null: false
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["impersonated_id"], name: "index_impersonation_sessions_on_impersonated_id"
    t.index ["impersonator_id"], name: "index_impersonation_sessions_on_impersonator_id"
  end

  create_table "import_mappings", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.boolean "create_when_empty", default: true
    t.datetime "created_at", null: false
    t.uuid "import_id", null: false
    t.string "key"
    t.uuid "mappable_id"
    t.string "mappable_type"
    t.string "type", null: false
    t.datetime "updated_at", null: false
    t.string "value"
    t.index ["import_id"], name: "index_import_mappings_on_import_id"
    t.index ["mappable_type", "mappable_id"], name: "index_import_mappings_on_mappable"
  end

  create_table "import_rows", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "account"
    t.text "actions"
    t.boolean "active"
    t.string "amount"
    t.string "category"
    t.text "conditions"
    t.datetime "created_at", null: false
    t.string "currency"
    t.string "date"
    t.string "effective_date"
    t.string "entity_type"
    t.string "exchange_operating_mic"
    t.uuid "import_id", null: false
    t.string "name"
    t.text "notes"
    t.string "price"
    t.string "qty"
    t.string "resource_type"
    t.string "tags"
    t.string "ticker"
    t.datetime "updated_at", null: false
    t.index ["import_id"], name: "index_import_rows_on_import_id"
  end

  create_table "imports", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "account_col_label"
    t.uuid "account_id"
    t.string "amount_col_label"
    t.string "amount_type_inflow_value"
    t.string "amount_type_strategy", default: "signed_amount"
    t.string "category_col_label"
    t.string "col_sep", default: ","
    t.jsonb "column_mappings"
    t.datetime "created_at", null: false
    t.string "currency_col_label"
    t.string "date_col_label"
    t.string "date_format", default: "%m/%d/%Y"
    t.string "entity_type_col_label"
    t.string "error"
    t.string "exchange_operating_mic_col_label"
    t.uuid "family_id", null: false
    t.string "name_col_label"
    t.string "normalized_csv_str"
    t.string "notes_col_label"
    t.string "number_format"
    t.string "price_col_label"
    t.string "qty_col_label"
    t.string "raw_file_str"
    t.string "signage_convention", default: "inflows_positive"
    t.string "status"
    t.string "tags_col_label"
    t.string "ticker_col_label"
    t.string "type", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_imports_on_account_id"
    t.index ["family_id"], name: "index_imports_on_family_id"
  end

  create_table "investments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "locked_attributes", default: {}
    t.string "subtype"
    t.datetime "updated_at", null: false
  end

  create_table "invitations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "accepted_at"
    t.datetime "created_at", null: false
    t.string "email"
    t.datetime "expires_at"
    t.uuid "family_id", null: false
    t.uuid "inviter_id", null: false
    t.string "role"
    t.string "token"
    t.datetime "updated_at", null: false
    t.index ["email", "family_id"], name: "index_invitations_on_email_and_family_id", unique: true
    t.index ["email"], name: "index_invitations_on_email"
    t.index ["family_id"], name: "index_invitations_on_family_id"
    t.index ["inviter_id"], name: "index_invitations_on_inviter_id"
    t.index ["token"], name: "index_invitations_on_token", unique: true
  end

  create_table "invite_codes", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.index ["token"], name: "index_invite_codes_on_token", unique: true
  end

  create_table "llm_usages", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "completion_tokens", default: 0, null: false
    t.datetime "created_at", null: false
    t.decimal "estimated_cost", precision: 10, scale: 6
    t.uuid "family_id", null: false
    t.jsonb "metadata", default: {}
    t.string "model", null: false
    t.string "operation", null: false
    t.integer "prompt_tokens", default: 0, null: false
    t.string "provider", null: false
    t.integer "total_tokens", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["family_id", "created_at"], name: "index_llm_usages_on_family_id_and_created_at"
    t.index ["family_id", "operation"], name: "index_llm_usages_on_family_id_and_operation"
    t.index ["family_id"], name: "index_llm_usages_on_family_id"
  end

  create_table "loan_installments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.decimal "actual_amount", precision: 15, scale: 2
    t.datetime "created_at", null: false
    t.date "due_date", null: false
    t.integer "installment_no", null: false
    t.decimal "interest_amount", precision: 19, scale: 4, null: false
    t.date "last_payment_date"
    t.decimal "paid_interest", precision: 15, scale: 2, default: "0.0", null: false
    t.decimal "paid_principal", precision: 15, scale: 2, default: "0.0", null: false
    t.date "posted_on"
    t.decimal "principal_amount", precision: 19, scale: 4, null: false
    t.string "status", default: "planned", null: false
    t.decimal "total_amount", precision: 19, scale: 4, null: false
    t.uuid "transfer_id"
    t.datetime "updated_at", null: false
    t.index ["account_id", "due_date"], name: "idx_loan_installments_planned_due", where: "((status)::text = 'planned'::text)"
    t.index ["account_id", "installment_no"], name: "idx_loan_installments_posted_once", unique: true, where: "((status)::text = 'posted'::text)"
    t.index ["account_id", "status"], name: "idx_loan_installments_posted_by_account", where: "((status)::text = 'posted'::text)"
    t.index ["account_id", "status"], name: "index_loan_installments_on_account_id_and_status"
    t.index ["account_id"], name: "index_loan_installments_on_account_id"
    t.index ["last_payment_date"], name: "index_loan_installments_on_last_payment_date"
    t.index ["transfer_id"], name: "index_loan_installments_on_transfer_id"
  end

  create_table "loans", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.text "agreement_notes"
    t.text "collateral_desc"
    t.string "compliance_type", default: "conventional"
    t.string "counterparty_name"
    t.string "counterparty_type"
    t.datetime "created_at", null: false
    t.string "day_count"
    t.string "debt_kind"
    t.uuid "disbursement_account_id"
    t.text "early_repayment_policy"
    t.boolean "eir_enabled", default: false
    t.jsonb "extra"
    t.string "fintech_type"
    t.decimal "initial_balance", precision: 19, scale: 4
    t.date "initial_balance_date"
    t.decimal "initial_balance_override", precision: 19, scale: 4
    t.decimal "installment_amount", precision: 19, scale: 4
    t.string "institution_name"
    t.string "institution_type"
    t.decimal "interest_rate", precision: 10, scale: 3
    t.string "islamic_product_type"
    t.jsonb "late_fee_rule"
    t.string "late_penalty_type", default: "conventional_fee"
    t.string "lender_name"
    t.uuid "linked_contact_id"
    t.jsonb "locked_attributes", default: {}
    t.decimal "margin_rate", precision: 10, scale: 3
    t.text "notes"
    t.date "origination_date"
    t.string "payment_frequency", default: "MONTHLY"
    t.decimal "principal_amount", precision: 19, scale: 4
    t.string "product_type"
    t.decimal "profit_sharing_ratio", precision: 5, scale: 4
    t.decimal "rate_or_profit", precision: 10, scale: 4
    t.string "rate_type"
    t.string "schedule_method", default: "ANNUITY"
    t.date "start_date"
    t.string "subtype"
    t.integer "tenor_months"
    t.integer "term_months"
    t.datetime "updated_at", null: false
    t.string "witness_name"
    t.index ["compliance_type"], name: "index_loans_on_compliance_type"
    t.index ["counterparty_type"], name: "index_loans_on_counterparty_type"
    t.index ["debt_kind"], name: "index_loans_on_debt_kind"
    t.index ["disbursement_account_id"], name: "index_loans_on_disbursement_account_id"
    t.index ["fintech_type"], name: "index_loans_on_fintech_type"
    t.index ["institution_type"], name: "index_loans_on_institution_type"
    t.index ["islamic_product_type"], name: "index_loans_on_islamic_product_type"
    t.index ["lender_name"], name: "index_loans_on_lender_name"
    t.index ["linked_contact_id"], name: "index_loans_on_linked_contact_id"
  end

  create_table "lunchflow_accounts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "account_id"
    t.string "account_status"
    t.string "account_type"
    t.datetime "created_at", null: false
    t.string "currency"
    t.decimal "current_balance", precision: 19, scale: 4
    t.jsonb "institution_metadata"
    t.uuid "lunchflow_item_id", null: false
    t.string "name"
    t.string "provider"
    t.jsonb "raw_payload"
    t.jsonb "raw_transactions_payload"
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_lunchflow_accounts_on_account_id"
    t.index ["lunchflow_item_id"], name: "index_lunchflow_accounts_on_lunchflow_item_id"
  end

  create_table "lunchflow_items", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "family_id", null: false
    t.string "institution_color"
    t.string "institution_domain"
    t.string "institution_id"
    t.string "institution_name"
    t.string "institution_url"
    t.string "name"
    t.boolean "pending_account_setup", default: false
    t.jsonb "raw_institution_payload"
    t.jsonb "raw_payload"
    t.boolean "scheduled_for_deletion", default: false
    t.string "status", default: "good"
    t.datetime "sync_start_date"
    t.datetime "updated_at", null: false
    t.index ["family_id"], name: "index_lunchflow_items_on_family_id"
    t.index ["institution_id"], name: "index_lunchflow_items_on_institution_id"
    t.index ["status"], name: "index_lunchflow_items_on_status"
  end

  create_table "merchants", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.decimal "avg_monthly_cost", precision: 19, scale: 4
    t.string "billing_frequency"
    t.string "color"
    t.datetime "created_at", null: false
    t.text "description"
    t.uuid "family_id"
    t.string "logo_url"
    t.string "name", null: false
    t.boolean "popular", default: false
    t.string "provider_merchant_id"
    t.string "source"
    t.string "stripe_plan_id"
    t.string "stripe_product_id"
    t.string "subscription_category"
    t.string "support_email"
    t.string "type", null: false
    t.datetime "updated_at", null: false
    t.string "website_url"
    t.index ["family_id", "name"], name: "index_merchants_on_family_id_and_name", unique: true, where: "((type)::text = 'FamilyMerchant'::text)"
    t.index ["family_id"], name: "index_merchants_on_family_id"
    t.index ["popular"], name: "index_merchants_on_popular"
    t.index ["provider_merchant_id", "source"], name: "index_merchants_on_provider_merchant_id_and_source", unique: true, where: "((provider_merchant_id IS NOT NULL) AND ((type)::text = 'ProviderMerchant'::text))"
    t.index ["source", "name"], name: "index_merchants_on_source_and_name", unique: true, where: "((type)::text = 'ProviderMerchant'::text)"
    t.index ["stripe_plan_id"], name: "index_merchants_on_stripe_plan_id", unique: true, where: "(stripe_plan_id IS NOT NULL)"
    t.index ["stripe_product_id"], name: "index_merchants_on_stripe_product_id", unique: true, where: "(stripe_product_id IS NOT NULL)"
    t.index ["subscription_category"], name: "index_merchants_on_subscription_category"
    t.index ["type"], name: "index_merchants_on_type"
  end

  create_table "messages", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "ai_model"
    t.uuid "chat_id", null: false
    t.text "content"
    t.datetime "created_at", null: false
    t.boolean "debug", default: false
    t.string "provider_id"
    t.boolean "reasoning", default: false
    t.string "status", default: "complete", null: false
    t.string "type", null: false
    t.datetime "updated_at", null: false
    t.index ["chat_id"], name: "index_messages_on_chat_id"
    t.index ["provider_id"], name: "index_messages_on_provider_id"
  end

  create_table "mobile_devices", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "app_version"
    t.datetime "created_at", null: false
    t.string "device_id"
    t.string "device_name"
    t.string "device_type"
    t.datetime "last_seen_at"
    t.integer "oauth_application_id"
    t.string "os_version"
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["oauth_application_id"], name: "index_mobile_devices_on_oauth_application_id"
    t.index ["user_id", "device_id"], name: "index_mobile_devices_on_user_id_and_device_id", unique: true
    t.index ["user_id"], name: "index_mobile_devices_on_user_id"
  end

  create_table "oauth_access_grants", force: :cascade do |t|
    t.bigint "application_id", null: false
    t.datetime "created_at", null: false
    t.integer "expires_in", null: false
    t.text "redirect_uri", null: false
    t.string "resource_owner_id", null: false
    t.datetime "revoked_at"
    t.string "scopes", default: "", null: false
    t.string "token", null: false
    t.index ["application_id"], name: "index_oauth_access_grants_on_application_id"
    t.index ["resource_owner_id"], name: "index_oauth_access_grants_on_resource_owner_id"
    t.index ["token"], name: "index_oauth_access_grants_on_token", unique: true
  end

  create_table "oauth_access_tokens", force: :cascade do |t|
    t.bigint "application_id", null: false
    t.datetime "created_at", null: false
    t.integer "expires_in"
    t.string "previous_refresh_token", default: "", null: false
    t.string "refresh_token"
    t.string "resource_owner_id"
    t.datetime "revoked_at"
    t.string "scopes"
    t.string "token", null: false
    t.index ["application_id"], name: "index_oauth_access_tokens_on_application_id"
    t.index ["refresh_token"], name: "index_oauth_access_tokens_on_refresh_token", unique: true
    t.index ["resource_owner_id"], name: "index_oauth_access_tokens_on_resource_owner_id"
    t.index ["token"], name: "index_oauth_access_tokens_on_token", unique: true
  end

  create_table "oauth_applications", force: :cascade do |t|
    t.boolean "confidential", default: true, null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.uuid "owner_id"
    t.string "owner_type"
    t.text "redirect_uri", null: false
    t.string "scopes", default: "", null: false
    t.string "secret", null: false
    t.string "uid", null: false
    t.datetime "updated_at", null: false
    t.index ["owner_id", "owner_type"], name: "index_oauth_applications_on_owner_id_and_owner_type"
    t.index ["uid"], name: "index_oauth_applications_on_uid", unique: true
  end

  create_table "oidc_identities", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "info", default: {}
    t.datetime "last_authenticated_at"
    t.string "provider", null: false
    t.string "uid", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["provider", "uid"], name: "index_oidc_identities_on_provider_and_uid", unique: true
    t.index ["user_id"], name: "index_oidc_identities_on_user_id"
  end

  create_table "other_assets", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "locked_attributes", default: {}
    t.string "subtype"
    t.datetime "updated_at", null: false
  end

  create_table "other_liabilities", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "locked_attributes", default: {}
    t.string "subtype"
    t.datetime "updated_at", null: false
  end

  create_table "pay_later_installments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.decimal "applied_rate", precision: 9, scale: 6
    t.datetime "created_at", null: false
    t.date "due_date", null: false
    t.decimal "fee_amount", precision: 19, scale: 4, default: "0.0", null: false
    t.integer "installment_no", null: false
    t.decimal "interest_amount", precision: 19, scale: 4, null: false
    t.decimal "paid_amount", precision: 19, scale: 4
    t.date "paid_on"
    t.decimal "principal_amount", precision: 19, scale: 4, null: false
    t.string "status", default: "pending", null: false
    t.decimal "total_cost", precision: 19, scale: 4
    t.decimal "total_due", precision: 19, scale: 4, null: false
    t.uuid "transfer_id"
    t.datetime "updated_at", null: false
    t.index ["account_id", "installment_no"], name: "idx_paylater_installments_acct_no", unique: true
    t.index ["account_id"], name: "index_pay_later_installments_on_account_id"
    t.index ["transfer_id"], name: "index_pay_later_installments_on_transfer_id"
  end

  create_table "pay_later_rates", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "effective_date", null: false
    t.decimal "monthly_rate", precision: 9, scale: 6, null: false
    t.string "provider_name", null: false
    t.integer "tenor_months", null: false
    t.datetime "updated_at", null: false
    t.index ["provider_name", "tenor_months", "effective_date"], name: "idx_pay_later_rates_provider_tenor_eff", unique: true
  end

  create_table "pay_laters", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.date "approved_date"
    t.boolean "auto_update_rate", default: true, null: false
    t.decimal "available_credit", precision: 19, scale: 4
    t.string "compliance_type", default: "conventional"
    t.string "contract_url"
    t.datetime "created_at", null: false
    t.decimal "credit_limit", precision: 19, scale: 4
    t.string "currency_code", limit: 3, default: "IDR", null: false
    t.boolean "early_settlement_allowed", default: true, null: false
    t.decimal "early_settlement_fee", precision: 18, scale: 2
    t.decimal "exchange_rate_to_idr", precision: 18, scale: 6
    t.date "expiry_date"
    t.integer "free_interest_months", default: 0, null: false
    t.integer "grace_days", default: 0, null: false
    t.jsonb "interest_rate_table", default: {}
    t.boolean "is_compound", default: false, null: false
    t.decimal "late_fee_first7", precision: 19, scale: 4, default: "50000.0", null: false
    t.decimal "late_fee_per_day", precision: 19, scale: 4, default: "30000.0", null: false
    t.jsonb "locked_attributes", default: {}
    t.integer "max_tenor", default: 12, null: false
    t.text "notes"
    t.string "provider_name"
    t.string "status", default: "ACTIVE", null: false
    t.string "subtype"
    t.datetime "updated_at", null: false
    t.string "updated_by"
    t.index ["compliance_type"], name: "index_pay_laters_on_compliance_type"
  end

  create_table "personal_lendings", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.date "actual_return_date"
    t.text "agreement_notes"
    t.string "contact_info"
    t.string "counterparty_name", null: false
    t.datetime "created_at", null: false
    t.date "expected_return_date"
    t.boolean "has_written_agreement", default: false
    t.decimal "initial_amount", precision: 19, scale: 4
    t.string "lending_direction", null: false
    t.string "lending_type", default: "informal"
    t.string "relationship"
    t.string "reminder_frequency"
    t.datetime "updated_at", null: false
    t.string "witness_name"
    t.index ["expected_return_date"], name: "index_personal_lendings_on_expected_return_date"
    t.index ["lending_direction"], name: "index_personal_lendings_on_lending_direction"
    t.index ["lending_type"], name: "index_personal_lendings_on_lending_type"
  end

  create_table "plaid_accounts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.decimal "available_balance", precision: 19, scale: 4
    t.datetime "created_at", null: false
    t.string "currency", null: false
    t.decimal "current_balance", precision: 19, scale: 4
    t.string "mask"
    t.string "name", null: false
    t.string "plaid_id", null: false
    t.uuid "plaid_item_id", null: false
    t.string "plaid_subtype"
    t.string "plaid_type", null: false
    t.jsonb "raw_investments_payload", default: {}
    t.jsonb "raw_liabilities_payload", default: {}
    t.jsonb "raw_payload", default: {}
    t.jsonb "raw_transactions_payload", default: {}
    t.datetime "updated_at", null: false
    t.index ["plaid_id"], name: "index_plaid_accounts_on_plaid_id", unique: true
    t.index ["plaid_item_id"], name: "index_plaid_accounts_on_plaid_item_id"
  end

  create_table "plaid_items", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "access_token"
    t.string "available_products", default: [], array: true
    t.string "billed_products", default: [], array: true
    t.datetime "created_at", null: false
    t.uuid "family_id", null: false
    t.string "institution_color"
    t.string "institution_id"
    t.string "institution_url"
    t.string "name"
    t.string "next_cursor"
    t.string "plaid_id", null: false
    t.string "plaid_region", default: "us", null: false
    t.jsonb "raw_institution_payload", default: {}
    t.jsonb "raw_payload", default: {}
    t.boolean "scheduled_for_deletion", default: false
    t.string "status", default: "good", null: false
    t.datetime "updated_at", null: false
    t.index ["family_id"], name: "index_plaid_items_on_family_id"
    t.index ["institution_id"], name: "index_plaid_items_on_institution_id"
    t.index ["plaid_id"], name: "index_plaid_items_on_plaid_id", unique: true
  end

  create_table "precious_metals", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "account_number"
    t.string "account_status", default: "active"
    t.string "akad"
    t.datetime "created_at", null: false
    t.jsonb "locked_attributes", default: {}
    t.decimal "manual_price", precision: 19, scale: 8
    t.string "manual_price_currency", limit: 3
    t.uuid "preferred_funding_account_id"
    t.decimal "quantity", precision: 19, scale: 4, default: "0.0", null: false
    t.string "scheme_type"
    t.string "subtype"
    t.string "unit", default: "g", null: false
    t.datetime "updated_at", null: false
  end

  create_table "properties", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "area_unit"
    t.integer "area_value"
    t.datetime "created_at", null: false
    t.jsonb "locked_attributes", default: {}
    t.string "subtype"
    t.datetime "updated_at", null: false
    t.integer "year_built"
  end

  create_table "provider_directories", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "archived_at"
    t.string "country"
    t.datetime "created_at", null: false
    t.string "kind", default: "other", null: false
    t.string "name", null: false
    t.text "notes"
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.string "website"
    t.index "lower((name)::text), user_id", name: "index_provider_directories_on_user_id_and_lower_name", unique: true
    t.index ["user_id"], name: "index_provider_directories_on_user_id"
  end

  create_table "recurring_transactions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.decimal "amount", precision: 19, scale: 4, null: false
    t.datetime "created_at", null: false
    t.string "currency", null: false
    t.decimal "expected_amount_avg", precision: 19, scale: 4
    t.decimal "expected_amount_max", precision: 19, scale: 4
    t.decimal "expected_amount_min", precision: 19, scale: 4
    t.integer "expected_day_of_month", null: false
    t.uuid "family_id", null: false
    t.date "last_occurrence_date", null: false
    t.boolean "manual", default: false
    t.uuid "merchant_id"
    t.string "name"
    t.date "next_expected_date", null: false
    t.integer "occurrence_count", default: 0, null: false
    t.string "status", default: "active", null: false
    t.datetime "updated_at", null: false
    t.index ["family_id", "merchant_id", "amount", "currency"], name: "idx_recurring_txns_on_family_merchant_amount_currency", unique: true
    t.index ["family_id", "status"], name: "index_recurring_transactions_on_family_id_and_status"
    t.index ["family_id"], name: "index_recurring_transactions_on_family_id"
    t.index ["merchant_id"], name: "index_recurring_transactions_on_merchant_id"
    t.index ["next_expected_date"], name: "index_recurring_transactions_on_next_expected_date"
  end

  create_table "rejected_transfers", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "inflow_transaction_id", null: false
    t.uuid "outflow_transaction_id", null: false
    t.datetime "updated_at", null: false
    t.index ["inflow_transaction_id", "outflow_transaction_id"], name: "idx_on_inflow_transaction_id_outflow_transaction_id_412f8e7e26", unique: true
    t.index ["inflow_transaction_id"], name: "index_rejected_transfers_on_inflow_transaction_id"
    t.index ["outflow_transaction_id"], name: "index_rejected_transfers_on_outflow_transaction_id"
  end

  create_table "rule_actions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "action_type", null: false
    t.datetime "created_at", null: false
    t.uuid "rule_id", null: false
    t.datetime "updated_at", null: false
    t.string "value"
    t.index ["rule_id"], name: "index_rule_actions_on_rule_id"
  end

  create_table "rule_conditions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "condition_type", null: false
    t.datetime "created_at", null: false
    t.string "operator", null: false
    t.uuid "parent_id"
    t.uuid "rule_id"
    t.datetime "updated_at", null: false
    t.string "value"
    t.index ["parent_id"], name: "index_rule_conditions_on_parent_id"
    t.index ["rule_id"], name: "index_rule_conditions_on_rule_id"
  end

  create_table "rule_runs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error_message"
    t.datetime "executed_at", null: false
    t.string "execution_type", default: "manual", null: false
    t.integer "pending_jobs_count", default: 0, null: false
    t.uuid "rule_id", null: false
    t.string "rule_name"
    t.string "status", default: "pending", null: false
    t.integer "transactions_modified", default: 0, null: false
    t.integer "transactions_processed", default: 0, null: false
    t.integer "transactions_queued", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["executed_at"], name: "index_rule_runs_on_executed_at"
    t.index ["rule_id", "executed_at"], name: "index_rule_runs_on_rule_id_and_executed_at"
    t.index ["rule_id"], name: "index_rule_runs_on_rule_id"
  end

  create_table "rules", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.boolean "active", default: false, null: false
    t.datetime "created_at", null: false
    t.date "effective_date"
    t.uuid "family_id", null: false
    t.string "name"
    t.string "resource_type", null: false
    t.datetime "updated_at", null: false
    t.index ["family_id"], name: "index_rules_on_family_id"
  end

  create_table "securities", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "country_code"
    t.datetime "created_at", null: false
    t.string "exchange_acronym"
    t.string "exchange_mic"
    t.string "exchange_operating_mic"
    t.datetime "failed_fetch_at"
    t.integer "failed_fetch_count", default: 0, null: false
    t.datetime "last_health_check_at"
    t.string "logo_url"
    t.string "name"
    t.boolean "offline", default: false, null: false
    t.string "ticker", null: false
    t.datetime "updated_at", null: false
    t.index "upper((ticker)::text), COALESCE(upper((exchange_operating_mic)::text), ''::text)", name: "index_securities_on_ticker_and_exchange_operating_mic_unique", unique: true
    t.index ["country_code"], name: "index_securities_on_country_code"
    t.index ["exchange_operating_mic"], name: "index_securities_on_exchange_operating_mic"
  end

  create_table "security_prices", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "currency", default: "USD", null: false
    t.date "date", null: false
    t.decimal "price", precision: 19, scale: 4, null: false
    t.boolean "provisional", default: false, null: false
    t.uuid "security_id"
    t.datetime "updated_at", null: false
    t.index ["security_id", "date", "currency"], name: "index_security_prices_on_security_id_and_date_and_currency", unique: true
    t.index ["security_id"], name: "index_security_prices_on_security_id"
  end

  create_table "services", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.boolean "auto_detected", default: false, null: false
    t.decimal "avg_monthly_cost", precision: 19, scale: 4
    t.string "billing_frequency", default: "monthly"
    t.string "category", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "logo"
    t.string "name", null: false
    t.boolean "popular", default: false, null: false
    t.string "stripe_plan_id"
    t.string "stripe_product_id"
    t.string "support_email"
    t.datetime "updated_at", null: false
    t.integer "usage_count", default: 0
    t.string "website"
    t.index ["auto_detected"], name: "index_services_on_auto_detected"
    t.index ["category"], name: "index_services_on_category"
    t.index ["name"], name: "index_services_on_name", unique: true
    t.index ["popular"], name: "index_services_on_popular"
    t.index ["stripe_plan_id"], name: "index_services_on_stripe_plan_id", unique: true, where: "(stripe_plan_id IS NOT NULL)"
    t.index ["stripe_product_id"], name: "index_services_on_stripe_product_id", unique: true, where: "(stripe_product_id IS NOT NULL)"
  end

  create_table "sessions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "active_impersonator_session_id"
    t.datetime "created_at", null: false
    t.jsonb "data", default: {}
    t.string "ip_address"
    t.jsonb "prev_transaction_page_params", default: {}
    t.datetime "subscribed_at"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.uuid "user_id", null: false
    t.index ["active_impersonator_session_id"], name: "index_sessions_on_active_impersonator_session_id"
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "settings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "value"
    t.string "var", null: false
    t.index ["var"], name: "index_settings_on_var", unique: true
  end

  create_table "simplefin_accounts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "account_id"
    t.string "account_subtype"
    t.string "account_type"
    t.decimal "available_balance", precision: 19, scale: 4
    t.datetime "balance_date"
    t.datetime "created_at", null: false
    t.string "currency"
    t.decimal "current_balance", precision: 19, scale: 4
    t.jsonb "extra"
    t.string "name"
    t.jsonb "org_data"
    t.jsonb "raw_holdings_payload"
    t.jsonb "raw_payload"
    t.jsonb "raw_transactions_payload"
    t.uuid "simplefin_item_id", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_simplefin_accounts_on_account_id"
    t.index ["simplefin_item_id"], name: "index_simplefin_accounts_on_simplefin_item_id"
  end

  create_table "simplefin_items", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.text "access_url"
    t.datetime "created_at", null: false
    t.uuid "family_id", null: false
    t.string "institution_color"
    t.string "institution_domain"
    t.string "institution_id"
    t.string "institution_name"
    t.string "institution_url"
    t.string "name"
    t.boolean "pending_account_setup", default: false, null: false
    t.jsonb "raw_institution_payload"
    t.jsonb "raw_payload"
    t.boolean "scheduled_for_deletion", default: false
    t.string "status", default: "good"
    t.date "sync_start_date"
    t.datetime "updated_at", null: false
    t.index ["family_id"], name: "index_simplefin_items_on_family_id"
    t.index ["institution_domain"], name: "index_simplefin_items_on_institution_domain"
    t.index ["institution_id"], name: "index_simplefin_items_on_institution_id"
    t.index ["institution_name"], name: "index_simplefin_items_on_institution_name"
    t.index ["status"], name: "index_simplefin_items_on_status"
  end

  create_table "subscription_plans", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.decimal "amount", precision: 19, scale: 4, null: false
    t.boolean "archived", default: false, null: false
    t.boolean "auto_renew", default: true, null: false
    t.string "billing_cycle", default: "monthly", null: false
    t.date "cancelled_at"
    t.datetime "created_at", null: false
    t.string "currency", default: "USD", null: false
    t.text "description"
    t.date "expires_at"
    t.boolean "failed_payment_alert_sent", default: false, null: false
    t.uuid "family_id", null: false
    t.date "last_renewal_at"
    t.integer "max_usage_allowed"
    t.uuid "merchant_id"
    t.jsonb "metadata", default: {}
    t.string "name", null: false
    t.date "next_billing_at", null: false
    t.string "payment_method", default: "manual", null: false
    t.text "payment_notes"
    t.uuid "service_id"
    t.boolean "shared_within_family", default: false, null: false
    t.date "started_at", null: false
    t.string "status", default: "active", null: false
    t.string "stripe_customer_id"
    t.string "stripe_subscription_id"
    t.date "trial_ends_at"
    t.datetime "updated_at", null: false
    t.integer "usage_count", default: 0
    t.index ["account_id"], name: "index_subscription_plans_on_account_id"
    t.index ["archived"], name: "index_subscription_plans_on_archived"
    t.index ["family_id", "next_billing_at"], name: "index_subscription_plans_on_family_id_and_next_billing_at"
    t.index ["family_id", "service_id"], name: "index_subscription_plans_on_family_id_and_service_id", unique: true
    t.index ["family_id", "status"], name: "index_subscription_plans_on_family_id_and_status"
    t.index ["family_id"], name: "index_subscription_plans_on_family_id"
    t.index ["merchant_id"], name: "index_subscription_plans_on_merchant_id"
    t.index ["service_id"], name: "index_subscription_plans_on_service_id"
    t.index ["status", "next_billing_at"], name: "index_subscription_plans_on_status_and_next_billing_at"
    t.index ["stripe_subscription_id"], name: "index_subscription_plans_on_stripe_subscription_id", unique: true, where: "(stripe_subscription_id IS NOT NULL)"
  end

  create_table "subscriptions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.decimal "amount", precision: 19, scale: 4
    t.datetime "created_at", null: false
    t.string "currency"
    t.datetime "current_period_ends_at"
    t.uuid "family_id", null: false
    t.string "interval"
    t.string "status", null: false
    t.string "stripe_id"
    t.datetime "trial_ends_at"
    t.datetime "updated_at", null: false
    t.index ["family_id"], name: "index_subscriptions_on_family_id", unique: true
    t.index ["stripe_id"], name: "index_subscriptions_on_stripe_id"
  end

  create_table "syncs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.jsonb "data"
    t.string "error"
    t.datetime "failed_at"
    t.uuid "parent_id"
    t.datetime "pending_at"
    t.string "status", default: "pending"
    t.text "sync_stats"
    t.uuid "syncable_id", null: false
    t.string "syncable_type", null: false
    t.datetime "syncing_at"
    t.datetime "updated_at", null: false
    t.date "window_end_date"
    t.date "window_start_date"
    t.index ["parent_id"], name: "index_syncs_on_parent_id"
    t.index ["status"], name: "index_syncs_on_status"
    t.index ["syncable_type", "syncable_id"], name: "index_syncs_on_syncable"
  end

  create_table "taggings", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "tag_id", null: false
    t.uuid "taggable_id"
    t.string "taggable_type"
    t.datetime "updated_at", null: false
    t.index ["tag_id"], name: "index_taggings_on_tag_id"
    t.index ["taggable_type", "taggable_id"], name: "index_taggings_on_taggable"
  end

  create_table "tags", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "color", default: "#e99537", null: false
    t.datetime "created_at", null: false
    t.uuid "family_id", null: false
    t.string "name"
    t.datetime "updated_at", null: false
    t.index ["family_id"], name: "index_tags_on_family_id"
  end

  create_table "tool_calls", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "function_arguments"
    t.string "function_name"
    t.jsonb "function_result"
    t.uuid "message_id", null: false
    t.string "provider_call_id"
    t.string "provider_id", null: false
    t.string "type", null: false
    t.datetime "updated_at", null: false
    t.index ["message_id"], name: "index_tool_calls_on_message_id"
    t.index ["provider_call_id"], name: "index_tool_calls_on_provider_call_id"
    t.index ["provider_id"], name: "index_tool_calls_on_provider_id"
  end

  create_table "trades", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "currency"
    t.jsonb "locked_attributes", default: {}
    t.decimal "price", precision: 19, scale: 10
    t.decimal "qty", precision: 19, scale: 4
    t.uuid "security_id", null: false
    t.datetime "updated_at", null: false
    t.index ["security_id"], name: "index_trades_on_security_id"
  end

  create_table "transactions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "category_id"
    t.datetime "created_at", null: false
    t.string "external_id"
    t.jsonb "extra", default: {}, null: false
    t.boolean "is_sharia_compliant", default: true
    t.string "islamic_transaction_type"
    t.string "kind", default: "standard", null: false
    t.jsonb "locked_attributes", default: {}
    t.uuid "merchant_id"
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_transactions_on_category_id"
    t.index ["external_id"], name: "index_transactions_on_external_id"
    t.index ["extra"], name: "index_transactions_on_extra", using: :gin
    t.index ["is_sharia_compliant"], name: "index_transactions_on_is_sharia_compliant"
    t.index ["islamic_transaction_type"], name: "index_transactions_on_islamic_transaction_type"
    t.index ["kind"], name: "index_transactions_on_kind"
    t.index ["merchant_id"], name: "index_transactions_on_merchant_id"
  end

  create_table "transfers", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "inflow_transaction_id", null: false
    t.text "notes"
    t.uuid "outflow_transaction_id", null: false
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["inflow_transaction_id", "outflow_transaction_id"], name: "idx_on_inflow_transaction_id_outflow_transaction_id_8cd07a28bd", unique: true
    t.index ["inflow_transaction_id"], name: "index_transfers_on_inflow_transaction_id"
    t.index ["outflow_transaction_id"], name: "index_transfers_on_outflow_transaction_id"
    t.index ["status"], name: "index_transfers_on_status"
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.boolean "ai_enabled", default: false, null: false
    t.datetime "created_at", null: false
    t.string "default_account_order", default: "name_asc"
    t.string "default_period", default: "last_30_days", null: false
    t.string "email"
    t.uuid "family_id", null: false
    t.string "first_name"
    t.text "goals", default: [], array: true
    t.string "last_name"
    t.uuid "last_viewed_chat_id"
    t.datetime "onboarded_at"
    t.string "otp_backup_codes", default: [], array: true
    t.boolean "otp_required", default: false, null: false
    t.string "otp_secret"
    t.string "password_digest"
    t.string "role", default: "member", null: false
    t.datetime "rule_prompt_dismissed_at"
    t.boolean "rule_prompts_disabled", default: false
    t.datetime "set_onboarding_goals_at"
    t.datetime "set_onboarding_preferences_at"
    t.boolean "show_ai_sidebar", default: true
    t.boolean "show_sidebar", default: true
    t.string "theme", default: "system"
    t.string "unconfirmed_email"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["family_id"], name: "index_users_on_family_id"
    t.index ["last_viewed_chat_id"], name: "index_users_on_last_viewed_chat_id"
    t.index ["otp_secret"], name: "index_users_on_otp_secret", unique: true, where: "(otp_secret IS NOT NULL)"
  end

  create_table "valuations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "kind", default: "reconciliation", null: false
    t.jsonb "locked_attributes", default: {}
    t.datetime "updated_at", null: false
  end

  create_table "vehicles", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "locked_attributes", default: {}
    t.string "make"
    t.string "mileage_unit"
    t.integer "mileage_value"
    t.string "model"
    t.string "subtype"
    t.datetime "updated_at", null: false
    t.integer "year"
  end

  add_foreign_key "account_providers", "accounts"
  add_foreign_key "accounts", "families"
  add_foreign_key "accounts", "imports"
  add_foreign_key "accounts", "plaid_accounts"
  add_foreign_key "accounts", "provider_directories", column: "provider_id"
  add_foreign_key "accounts", "simplefin_accounts"
  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "api_keys", "users"
  add_foreign_key "balances", "accounts", on_delete: :cascade
  add_foreign_key "budget_categories", "budgets"
  add_foreign_key "budget_categories", "categories"
  add_foreign_key "budgets", "families"
  add_foreign_key "categories", "families"
  add_foreign_key "chats", "users"
  add_foreign_key "entries", "accounts"
  add_foreign_key "entries", "entries", column: "parent_entry_id", on_delete: :cascade
  add_foreign_key "entries", "imports"
  add_foreign_key "eval_results", "eval_runs"
  add_foreign_key "eval_results", "eval_samples"
  add_foreign_key "eval_runs", "eval_datasets"
  add_foreign_key "eval_samples", "eval_datasets"
  add_foreign_key "family_exports", "families"
  add_foreign_key "holdings", "account_providers"
  add_foreign_key "holdings", "accounts"
  add_foreign_key "holdings", "securities"
  add_foreign_key "impersonation_session_logs", "impersonation_sessions"
  add_foreign_key "impersonation_sessions", "users", column: "impersonated_id"
  add_foreign_key "impersonation_sessions", "users", column: "impersonator_id"
  add_foreign_key "import_rows", "imports"
  add_foreign_key "imports", "families"
  add_foreign_key "invitations", "families"
  add_foreign_key "invitations", "users", column: "inviter_id"
  add_foreign_key "llm_usages", "families"
  add_foreign_key "loan_installments", "accounts", on_delete: :cascade
  add_foreign_key "loan_installments", "transfers", on_delete: :nullify
  add_foreign_key "loans", "accounts", column: "disbursement_account_id"
  add_foreign_key "lunchflow_accounts", "lunchflow_items"
  add_foreign_key "lunchflow_items", "families"
  add_foreign_key "merchants", "families"
  add_foreign_key "messages", "chats"
  add_foreign_key "mobile_devices", "users"
  add_foreign_key "oauth_access_grants", "oauth_applications", column: "application_id"
  add_foreign_key "oauth_access_tokens", "oauth_applications", column: "application_id"
  add_foreign_key "oidc_identities", "users"
  add_foreign_key "pay_later_installments", "accounts", on_delete: :cascade
  add_foreign_key "pay_later_installments", "transfers", on_delete: :nullify
  add_foreign_key "plaid_accounts", "plaid_items"
  add_foreign_key "plaid_items", "families"
  add_foreign_key "precious_metals", "accounts", column: "preferred_funding_account_id", on_delete: :nullify
  add_foreign_key "provider_directories", "users"
  add_foreign_key "recurring_transactions", "families"
  add_foreign_key "recurring_transactions", "merchants"
  add_foreign_key "rejected_transfers", "transactions", column: "inflow_transaction_id"
  add_foreign_key "rejected_transfers", "transactions", column: "outflow_transaction_id"
  add_foreign_key "rule_actions", "rules"
  add_foreign_key "rule_conditions", "rule_conditions", column: "parent_id"
  add_foreign_key "rule_conditions", "rules"
  add_foreign_key "rule_runs", "rules"
  add_foreign_key "rules", "families"
  add_foreign_key "security_prices", "securities"
  add_foreign_key "sessions", "impersonation_sessions", column: "active_impersonator_session_id"
  add_foreign_key "sessions", "users"
  add_foreign_key "simplefin_accounts", "simplefin_items"
  add_foreign_key "simplefin_items", "families"
  add_foreign_key "subscription_plans", "accounts"
  add_foreign_key "subscription_plans", "families"
  add_foreign_key "subscription_plans", "merchants", on_delete: :nullify
  add_foreign_key "subscription_plans", "services"
  add_foreign_key "subscriptions", "families"
  add_foreign_key "syncs", "syncs", column: "parent_id"
  add_foreign_key "taggings", "tags"
  add_foreign_key "tags", "families"
  add_foreign_key "tool_calls", "messages"
  add_foreign_key "trades", "securities"
  add_foreign_key "transactions", "categories", on_delete: :nullify
  add_foreign_key "transactions", "merchants"
  add_foreign_key "transfers", "transactions", column: "inflow_transaction_id", on_delete: :cascade
  add_foreign_key "transfers", "transactions", column: "outflow_transaction_id", on_delete: :cascade
  add_foreign_key "users", "chats", column: "last_viewed_chat_id"
  add_foreign_key "users", "families"
end
