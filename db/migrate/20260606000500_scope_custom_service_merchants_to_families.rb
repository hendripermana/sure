class ScopeCustomServiceMerchantsToFamilies < ActiveRecord::Migration[8.1]
  INDEX_NAME = "idx_service_merchants_family_name_unique".freeze

  def up
    execute <<~SQL
      DO $$
      DECLARE
        service_record RECORD;
        family_record RECORD;
        scoped_service_id uuid;
      BEGIN
        FOR service_record IN
          SELECT *
          FROM merchants
          WHERE type = 'ServiceMerchant'
            AND family_id IS NULL
            AND COALESCE(popular, false) = false
        LOOP
          FOR family_record IN
            SELECT DISTINCT family_id
            FROM subscription_plans
            WHERE merchant_id = service_record.id
          LOOP
            SELECT id
            INTO scoped_service_id
            FROM merchants
            WHERE type = 'ServiceMerchant'
              AND family_id = family_record.family_id
              AND name = service_record.name
            LIMIT 1;

            IF scoped_service_id IS NULL THEN
              scoped_service_id := gen_random_uuid();

              INSERT INTO merchants (
                id,
                avg_monthly_cost,
                billing_frequency,
                color,
                created_at,
                description,
                family_id,
                logo_url,
                name,
                popular,
                subscription_category,
                support_email,
                type,
                updated_at,
                website_url
              ) VALUES (
                scoped_service_id,
                service_record.avg_monthly_cost,
                service_record.billing_frequency,
                service_record.color,
                service_record.created_at,
                service_record.description,
                family_record.family_id,
                service_record.logo_url,
                service_record.name,
                false,
                service_record.subscription_category,
                service_record.support_email,
                service_record.type,
                service_record.updated_at,
                service_record.website_url
              );
            END IF;

            UPDATE subscription_plans
            SET merchant_id = scoped_service_id
            WHERE merchant_id = service_record.id
              AND family_id = family_record.family_id;
          END LOOP;
        END LOOP;
      END
      $$;
    SQL

    add_index :merchants,
      [ :family_id, :name ],
      unique: true,
      where: "type = 'ServiceMerchant' AND family_id IS NOT NULL",
      name: INDEX_NAME
  end

  def down
    remove_index :merchants, name: INDEX_NAME, if_exists: true
  end
end
