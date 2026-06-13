class Demo::IdrGenerator < Demo::Generator
  # Generate comprehensive realistic demo data with IDR currency and Indonesian features
  def generate_idr_data!(skip_clear: false, email: "user@sure.id")
    if skip_clear
      puts "⏭️  Skipping data clearing (appending new family)..."
    else
      puts "🧹 Clearing existing data..."
      clear_all_data!
    end

    with_timing(__method__, max_seconds: 1000) do
      puts "👥 Creating Indonesian demo family..."
      family = create_family_and_users!("Keluarga Demo", email, onboarded: true, subscribed: true)

      puts "📊 Creating realistic Indonesian financial data..."
      create_indonesian_categories!(family)
      create_indonesian_accounts!(family)
      create_indonesian_transactions!(family)
      # Auto-fill current-month budget based on recent spending averages
      generate_budget_auto_fill!(family)

      puts "✅ Indonesian demo data loaded successfully!"
    end
  end

  # Generate IDR demo data with enhanced personal lending features
  def generate_idr_personal_lending_data!(skip_clear: false, email: "user@sure.id")
    if skip_clear
      puts "⏭️  Skipping data clearing (appending new family)..."
    else
      puts "🧹 Clearing existing data..."
      clear_all_data!
    end

    with_timing(__method__, max_seconds: 1000) do
      puts "👥 Creating Indonesian demo family with personal lending..."
      family = create_family_and_users!("Keluarga Demo", email, onboarded: true, subscribed: true)

      puts "📊 Creating realistic Indonesian financial data with personal lending..."
      create_indonesian_categories!(family)
      create_indonesian_accounts_with_personal_lending!(family)
      create_indonesian_transactions_with_personal_lending!(family)
      # Auto-fill current-month budget based on recent spending averages
      generate_budget_auto_fill!(family)

      puts "✅ Indonesian personal lending demo data loaded successfully!"
    end
  end

  private

    # Override family creation to use Indonesian settings
    def create_family_and_users!(family_name, email, onboarded:, subscribed:)
      family = Family.create!(
        name: family_name,
        currency: "IDR",
        locale: "id",
        country: "ID",
        timezone: "Asia/Jakarta",
        date_format: "%d-%m-%Y"
      )

      family.start_subscription!("sub_demo_123") if subscribed

      # Admin user
      family.users.create!(
        email: email,
        first_name: "Demo (admin)",
        last_name: "Sure",
        role: "admin",
        password: "password",
        onboarded_at: onboarded ? Time.current : nil
      )

      # Member user
      family.users.create!(
        email: "partner_#{email}",
        first_name: "Demo (member)",
        last_name: "Sure",
        role: "member",
        password: "password",
        onboarded_at: onboarded ? Time.current : nil
      )

      family
    end

    # Convert USD amounts to realistic IDR amounts

    # Create Indonesian-specific categories
    def create_indonesian_categories!(family)
      puts "   🏷️  Creating Indonesian categories..."

      # Income categories
      @salary_cat = family.categories.create!(name: "Gaji", classification: "income", color: "#10B981", lucide_icon: "briefcase")
      @bonus_cat = family.categories.create!(name: "Bonus & THR", classification: "income", color: "#059669", lucide_icon: "award")
      @investment_income_cat = family.categories.create!(name: "Pendapatan Investasi", classification: "income", color: "#047857", lucide_icon: "trending-up")

      # Expense categories with Indonesian context
      @housing_cat = family.categories.create!(name: "Perumahan", classification: "expense", color: "#EF4444", lucide_icon: "house")
      @food_cat = family.categories.create!(name: "Makanan & Minuman", classification: "expense", color: "#F97316", lucide_icon: "utensils")
      @transportation_cat = family.categories.create!(name: "Transportasi", classification: "expense", color: "#EAB308", lucide_icon: "bus")
      @utilities_cat = family.categories.create!(name: "Listrik & Air", classification: "expense", color: "#84CC16", lucide_icon: "lightbulb")
      @healthcare_cat = family.categories.create!(name: "Kesehatan", classification: "expense", color: "#06B6D4", lucide_icon: "pill")
      @entertainment_cat = family.categories.create!(name: "Hiburan", classification: "expense", color: "#8B5CF6", lucide_icon: "drama")
      @shopping_cat = family.categories.create!(name: "Belanja", classification: "expense", color: "#EC4899", lucide_icon: "shopping-cart")
      @education_cat = family.categories.create!(name: "Pendidikan", classification: "expense", color: "#6366F1", lucide_icon: "graduation-cap")
      @personal_care_cat = family.categories.create!(name: "Perawatan Diri", classification: "expense", color: "#F59E0B", lucide_icon: "hand-helping")
      @travel_cat = family.categories.create!(name: "Perjalanan", classification: "expense", color: "#10B981", lucide_icon: "trees")

      # Indonesian-specific categories
      @zakat_cat = family.categories.create!(name: "Zakat", classification: "expense", color: "#059669", lucide_icon: "shield-plus")
      @infaq_cat = family.categories.create!(name: "Infaq/Sedekah", classification: "expense", color: "#047857", lucide_icon: "hand-helping")
      @arisan_cat = family.categories.create!(name: "Arisan", classification: "expense", color: "#0D9488", lucide_icon: "circle-dollar-sign")
      @family_support_cat = family.categories.create!(name: "Bantuan Keluarga", classification: "expense", color: "#0F766E", lucide_icon: "baby")

      # Interest and fees
      @interest_cat = family.categories.create!(name: "Bunga & Biaya", classification: "expense", color: "#DC2626", lucide_icon: "credit-card")
      @bank_fees_cat = family.categories.create!(name: "Biaya Bank", classification: "expense", color: "#B91C1C", lucide_icon: "building")
    end

    # Create Indonesian bank accounts and financial instruments
    def create_indonesian_accounts!(family)
      puts "   🏦 Creating Indonesian accounts..."

      # Indonesian Banks (IDR)
      @bca_checking = family.accounts.create!(accountable: Depository.new, name: "BCA Tabungan", balance: 0, currency: "IDR")
      puts "   ✅ Created BCA account: #{@bca_checking.id}"
      @mandiri_checking = family.accounts.create!(accountable: Depository.new, name: "Mandiri Tabungan", balance: 0, currency: "IDR")
      @bni_savings = family.accounts.create!(accountable: Depository.new, name: "BNI Deposito", balance: 0, currency: "IDR")
      @bri_checking = family.accounts.create!(accountable: Depository.new, name: "BRI Tabungan", balance: 0, currency: "IDR")

      # Credit Cards (IDR)
      @bca_credit = family.accounts.create!(accountable: CreditCard.new, name: "BCA Credit Card", balance: 0, currency: "IDR")
      @mandiri_credit = family.accounts.create!(accountable: CreditCard.new, name: "Mandiri Credit Card", balance: 0, currency: "IDR")

      # Investment accounts (IDR)
      @bibit_investment = family.accounts.create!(accountable: Investment.new, name: "Bibit Reksadana", balance: 0, currency: "IDR")
      @stock_investment = family.accounts.create!(accountable: Investment.new, name: "Saham IDX", balance: 0, currency: "IDR")

      # Vehicles (IDR)
      @honda_civic = family.accounts.create!(accountable: Vehicle.new, name: "Honda Civic 2018", balance: 0, currency: "IDR")
      @yamaha_motor = family.accounts.create!(accountable: Vehicle.new, name: "Yamaha NMAX", balance: 0, currency: "IDR")

      # Crypto (IDR)
      @indodax_btc = family.accounts.create!(accountable: Crypto.new, name: "Indodax Bitcoin", balance: 0, currency: "IDR")

      loan_builder = ->(name, debt_kind: "institutional") {
        Loan.new(counterparty_name: name, debt_kind: debt_kind)
      }

      # Traditional Loans (IDR)
      @kpr_loan = family.accounts.create!(accountable: loan_builder.call("KPR BTN"), name: "KPR BTN", balance: 0, currency: "IDR")
      puts "   ✅ Created KPR loan: #{@kpr_loan.id}"
      @motor_loan = family.accounts.create!(accountable: loan_builder.call("Kredit Motor"), name: "Kredit Motor", balance: 0, currency: "IDR")
      @education_loan = family.accounts.create!(accountable: loan_builder.call("Kredit Pendidikan"), name: "Kredit Pendidikan", balance: 0, currency: "IDR")

      # Indonesian Fintech Loans
      @kredivo_loan = family.accounts.create!(accountable: loan_builder.call("Kredivo"), name: "Kredivo", balance: 0, currency: "IDR")
      @akulaku_loan = family.accounts.create!(accountable: loan_builder.call("Akulaku"), name: "Akulaku", balance: 0, currency: "IDR")
      @home_credit_loan = family.accounts.create!(accountable: loan_builder.call("Home Credit"), name: "Home Credit", balance: 0, currency: "IDR")

      # Personal Loans (Pinjam ke Orang) - Indonesian context
      @loan_from_family = family.accounts.create!(accountable: loan_builder.call("Pinjaman dari Ibu", debt_kind: "personal"), name: "Pinjaman dari Ibu", balance: 0, currency: "IDR")
      @loan_from_friend = family.accounts.create!(accountable: loan_builder.call("Pinjaman dari Teman", debt_kind: "personal"), name: "Pinjaman dari Teman", balance: 0, currency: "IDR")
      @loan_from_colleague = family.accounts.create!(accountable: loan_builder.call("Pinjaman dari Rekan Kerja", debt_kind: "personal"), name: "Pinjaman dari Rekan Kerja", balance: 0, currency: "IDR")

      # Other liabilities
      @personal_loc = family.accounts.create!(accountable: OtherLiability.new, name: "Kredit Tanpa Agunan", balance: 0, currency: "IDR")

      # Other assets
      @gold_investment = family.accounts.create!(accountable: OtherAsset.new, name: "Investasi Emas", balance: 0, currency: "IDR")
    end

    # Create Indonesian accounts with personal lending features
    def create_indonesian_accounts_with_personal_lending!(family)
      create_indonesian_accounts!(family)

      puts "   🤝 Creating personal lending accounts..."

      # Personal lending accounts (money lent out to others)
      @lending_to_family = family.accounts.create!(
        accountable: PersonalLending.new(
          counterparty_name: "Ahmad (Saudara)",
          lending_direction: "lending_out",
          lending_type: "qard_hasan",
          relationship: "family",
          initial_amount: 5_000_000,
          expected_return_date: 6.months.from_now,
          reminder_frequency: "monthly"
        ),
        name: "Pinjaman ke Ahmad",
        balance: 0,
        currency: "IDR"
      )

      @lending_to_friend = family.accounts.create!(
        accountable: PersonalLending.new(
          counterparty_name: "Budi (Teman)",
          lending_direction: "lending_out",
          lending_type: "informal_with_agreement",
          relationship: "friend",
          initial_amount: 3_000_000,
          expected_return_date: 3.months.from_now,
          reminder_frequency: "before_due"
        ),
        name: "Pinjaman ke Budi",
        balance: 0,
        currency: "IDR"
      )

      @lending_to_colleague = family.accounts.create!(
        accountable: PersonalLending.new(
          counterparty_name: "Siti (Rekan Kerja)",
          lending_direction: "lending_out",
          lending_type: "interest_free",
          relationship: "colleague",
          initial_amount: 2_000_000,
          expected_return_date: 2.months.from_now,
          reminder_frequency: "weekly"
        ),
        name: "Pinjaman ke Siti",
        balance: 0,
        currency: "IDR"
      )
    end

    # Create Indonesian transactions with realistic amounts
    def create_indonesian_transactions!(family)
      load_securities!

      puts "   📈 Generating Indonesian salary history (12 years)..."
      generate_indonesian_salary_history!

      puts "   🏠 Generating housing transactions..."
      generate_indonesian_housing_transactions!

      puts "   🍕 Generating food & dining transactions..."
      generate_indonesian_food_transactions!

      puts "   🚗 Generating transportation transactions..."
      generate_indonesian_transportation_transactions!

      puts "   🎬 Generating entertainment transactions..."
      generate_indonesian_entertainment_transactions!

      puts "   🛒 Generating shopping transactions..."
      generate_indonesian_shopping_transactions!

      puts "   ⚕️ Generating healthcare transactions..."
      generate_indonesian_healthcare_transactions!

      puts "   ✈️ Generating travel transactions..."
      generate_indonesian_travel_transactions!

      puts "   💅 Generating personal care transactions..."
      generate_indonesian_personal_care_transactions!

      puts "   💰 Generating investment transactions..."
      generate_indonesian_investment_transactions!

      puts "   🏡 Generating major purchases..."
      generate_indonesian_major_purchases!

      puts "   💳 Generating transfers and payments..."
      generate_indonesian_transfers_and_payments!

      puts "   🏦 Generating Indonesian loan payments..."
      generate_indonesian_loan_payments!

      puts "   🧾 Generating regular expense baseline..."
      generate_indonesian_regular_expenses!

      puts "   🗄️  Generating legacy historical data..."
      generate_indonesian_legacy_transactions!

      puts "   🔒 Generating crypto & misc asset transactions..."
      generate_indonesian_crypto_and_misc_assets!

      puts "   ✅ Reconciling balances to target snapshot..."
      reconcile_balances!(family)

      puts "   📊 Generated approximately #{Entry.joins(:account).where(accounts: { family_id: family.id }).count} transactions"

      puts "🔄 Final sync to calculate adjusted balances..."
      sync_family_accounts!(family)
    end

    # Create Indonesian transactions with personal lending
    def create_indonesian_transactions_with_personal_lending!(family)
      create_indonesian_transactions!(family)

      puts "   🤝 Generating personal lending transactions..."
      generate_personal_lending_transactions!

      puts "   🔄 Final sync to calculate adjusted balances..."
      sync_family_accounts!(family)
    end

    # Generate Indonesian salary history with realistic amounts
    def generate_indonesian_salary_history!
      # Start with entry-level salary 12 years ago (fresh graduate)
      base_salary = 3_000_000 # 3 million IDR (realistic fresh graduate)
      current_salary = 8_000_000 # 8 million IDR (realistic mid-level)

      # Generate salary progression over 12 years
      (0..11).each do |year|
        year_date = (12 - year).years.ago.beginning_of_year
        salary_amount = base_salary + ((current_salary - base_salary) * (year / 11.0))

        # Monthly salary payments
        (0..11).each do |month|
          payment_date = year_date + month.months + rand(1..5).days
          create_transaction!(@bca_checking, salary_amount, "Gaji Bulanan", @salary_cat, payment_date)

          # THR (Tunjangan Hari Raya) in June and December
          if [ 5, 11 ].include?(month)
            thr_amount = salary_amount * 0.5 # Half month salary
            create_transaction!(@bca_checking, thr_amount, "THR", @bonus_cat, payment_date)
          end
        end
      end
    end

    # Generate Indonesian housing transactions
    def generate_indonesian_housing_transactions!
      # KPR (Kredit Pemilikan Rumah) - Home ownership credit
      kpr_date = 5.years.ago.to_date
      down_payment = 50_000_000 # 50 million IDR down payment (realistic)
      kpr_principal = 300_000_000 # 300 million IDR KPR (realistic for small house)

      create_transaction!(@bca_checking, down_payment, "DP KPR", @housing_cat, kpr_date)
      # Origination: move proceeds from loan liability to checking as a single transfer
      create_transfer!(@kpr_loan, @bca_checking, kpr_principal, "KPR Proceeds", kpr_date)

      # Monthly housing expenses
      date_cursor = 36.months.ago.beginning_of_month
      while date_cursor <= Date.current
        payment_date = first_business_day(date_cursor)

        # KPR payment
        make_loan_payment!(
          principal_account: @kpr_loan,
          principal_amount: 1_500_000, # 1.5 million IDR principal
          interest_amount: 1_800_000,  # 1.8 million IDR interest
          interest_category: @housing_cat,
          date: payment_date,
          memo: "Cicilan KPR"
        )

        # Utilities
        create_transaction!(@bca_checking, 200_000, "Listrik PLN", @utilities_cat, payment_date)
        create_transaction!(@bca_checking, 50_000, "PDAM Air", @utilities_cat, payment_date)
        create_transaction!(@bca_checking, 150_000, "Internet", @utilities_cat, payment_date)

        date_cursor = date_cursor.next_month.beginning_of_month
      end
    end

    # Generate Indonesian food transactions
    def generate_indonesian_food_transactions!
      date_cursor = 12.months.ago.beginning_of_month
      while date_cursor <= Date.current
        # Daily food expenses
        (0..29).each do |day|
          next if rand > 0.8 # Skip some days randomly

          food_date = date_cursor + day.days

          # Warung/restaurant meals
          if rand > 0.5
            create_transaction!(@bca_checking, 20_000, "Makan Siang", @food_cat, food_date)
          end

          # Groceries
          if rand > 0.7
            create_transaction!(@bca_checking, 75_000, "Belanja Pasar", @food_cat, food_date)
          end
        end

        date_cursor = date_cursor.next_month.beginning_of_month
      end
    end

    # Generate Indonesian transportation transactions
    def generate_indonesian_transportation_transactions!
      date_cursor = 12.months.ago.beginning_of_month
      while date_cursor <= Date.current
        # Daily transportation
        (0..29).each do |day|
          next if rand > 0.6 # Skip some days randomly

          transport_date = date_cursor + day.days

          # Gojek/Grab rides
          if rand > 0.7
            create_transaction!(@bca_checking, 25_000, "Ojek Online", @transportation_cat, transport_date)
          end

          # Public transport
          if rand > 0.5
            create_transaction!(@bca_checking, 3_500, "Transjakarta", @transportation_cat, transport_date)
          end
        end

        # Monthly fuel
        fuel_date = first_business_day(date_cursor)
        create_transaction!(@bca_checking, 300_000, "BBM Motor", @transportation_cat, fuel_date)

        date_cursor = date_cursor.next_month.beginning_of_month
      end
    end

    # Generate Indonesian loan payments including fintech loans
    def generate_indonesian_loan_payments!
      date_cursor = 36.months.ago.beginning_of_month
      while date_cursor <= Date.current
        payment_date = first_business_day(date_cursor)

        # KPR payment (already handled in housing transactions)

        # Motor loan
        make_loan_payment!(
          principal_account: @motor_loan,
          principal_amount: 400_000, # 400k IDR
          interest_amount: 100_000, # 100k IDR
          interest_category: @transportation_cat,
          date: payment_date,
          memo: "Cicilan Motor"
        )

        # Education loan
        make_loan_payment!(
          principal_account: @education_loan,
          principal_amount: 600_000, # 600k IDR
          interest_amount: 150_000, # 150k IDR
          interest_category: @education_cat,
          date: payment_date,
          memo: "Cicilan Pendidikan"
        )

        # Personal loans (pinjam ke orang) - more realistic amounts
        if rand > 0.3 # Not every month
          make_loan_payment!(
            principal_account: @loan_from_family,
            principal_amount: 200_000, # 200k IDR
            interest_amount: 0, # Interest-free from family
            interest_category: @family_support_cat,
            date: payment_date,
            memo: "Cicilan Pinjaman dari Ibu"
          )
        end

        if rand > 0.4 # Not every month
          make_loan_payment!(
            principal_account: @loan_from_friend,
            principal_amount: 150_000, # 150k IDR
            interest_amount: 0, # Interest-free from friend
            interest_category: @family_support_cat,
            date: payment_date,
            memo: "Cicilan Pinjaman dari Teman"
          )
        end

        # Fintech loans (higher interest rates)
        if rand > 0.3 # Not every month
          make_loan_payment!(
            principal_account: @kredivo_loan,
            principal_amount: 500_000, # 500k IDR
            interest_amount: 150_000, # 150k IDR
            interest_category: @interest_cat,
            date: payment_date,
            memo: "Cicilan Kredivo"
          )
        end

        if rand > 0.4 # Not every month
          make_loan_payment!(
            principal_account: @akulaku_loan,
            principal_amount: 300_000, # 300k IDR
            interest_amount: 100_000, # 100k IDR
            interest_category: @interest_cat,
            date: payment_date,
            memo: "Cicilan Akulaku"
          )
        end

        date_cursor = date_cursor.next_month.beginning_of_month
      end
    end

    # Generate personal lending transactions
    def generate_personal_lending_transactions!
      # Initial lending transactions
      lending_date = 6.months.ago.to_date

      # Lend money to family member (Qard Hasan)
      create_transfer!(@bca_checking, @lending_to_family, 5_000_000, "Pinjaman Qard Hasan", lending_date)

      # Lend money to friend
      friend_lending_date = 3.months.ago.to_date
      create_transfer!(@bca_checking, @lending_to_friend, 3_000_000, "Pinjaman ke Teman", friend_lending_date)

      # Lend money to colleague
      colleague_lending_date = 2.months.ago.to_date
      create_transfer!(@bca_checking, @lending_to_colleague, 2_000_000, "Pinjaman ke Rekan", colleague_lending_date)

      # Some partial repayments
      if rand > 0.5
        repayment_date = 1.month.ago.to_date
        create_transfer!(@lending_to_friend, @bca_checking, 1_000_000, "Pengembalian dari Budi", repayment_date)
      end
    end

    # Generate Indonesian-specific transactions
    def generate_indonesian_entertainment_transactions!
      date_cursor = 12.months.ago.beginning_of_month
      while date_cursor <= Date.current
        # Monthly entertainment
        entertainment_date = first_business_day(date_cursor)

        # Netflix/streaming
        create_transaction!(@bca_checking, 150_000, "Netflix", @entertainment_cat, entertainment_date)

        # Cinema
        if rand > 0.5
          create_transaction!(@bca_checking, 100_000, "Bioskop", @entertainment_cat, entertainment_date)
        end

        date_cursor = date_cursor.next_month.beginning_of_month
      end
    end

    def generate_indonesian_shopping_transactions!
      date_cursor = 12.months.ago.beginning_of_month
      while date_cursor <= Date.current
        # Monthly shopping
        shopping_date = first_business_day(date_cursor)

        # Online shopping (Tokopedia, Shopee)
        if rand > 0.3
          create_transaction!(@bca_checking, 500_000, "Belanja Online", @shopping_cat, shopping_date)
        end

        date_cursor = date_cursor.next_month.beginning_of_month
      end
    end

    def generate_indonesian_healthcare_transactions!
      date_cursor = 12.months.ago.beginning_of_month
      while date_cursor <= Date.current
        # Monthly healthcare
        healthcare_date = first_business_day(date_cursor)

        # BPJS Kesehatan
        create_transaction!(@bca_checking, 100_000, "BPJS Kesehatan", @healthcare_cat, healthcare_date)

        # Doctor visits
        if rand > 0.7
          create_transaction!(@bca_checking, 200_000, "Kunjungan Dokter", @healthcare_cat, healthcare_date)
        end

        date_cursor = date_cursor.next_month.beginning_of_month
      end
    end

    def generate_indonesian_travel_transactions!
      # Domestic travel
      travel_dates = [ 6.months.ago, 3.months.ago, 1.month.ago ].select { rand > 0.3 }

      travel_dates.each do |travel_date|
        create_transaction!(@bca_checking, 2_000_000, "Liburan Domestik", @travel_cat, travel_date)
      end
    end

    def generate_indonesian_personal_care_transactions!
      date_cursor = 12.months.ago.beginning_of_month
      while date_cursor <= Date.current
        # Monthly personal care
        care_date = first_business_day(date_cursor)

        # Haircut
        if rand > 0.5
          create_transaction!(@bca_checking, 50_000, "Potong Rambut", @personal_care_cat, care_date)
        end

        date_cursor = date_cursor.next_month.beginning_of_month
      end
    end

    def generate_indonesian_investment_transactions!
      date_cursor = 12.months.ago.beginning_of_month
      while date_cursor <= Date.current
        investment_date = first_business_day(date_cursor)

        # Reksadana investment
        if rand > 0.4
          # Single transfer to represent the investment cash movement
          create_transfer!(@bca_checking, @bibit_investment, 1_000_000, "Investasi Reksadana", investment_date)
          # Optionally categorize the outflow side after creation if supported:
          # outflow = @bca_checking.entries.where(date: investment_date, name: "Investasi Reksadana").last
          # outflow.entryable.update!(category: @investment_income_cat) if outflow&.transaction?
        end

        date_cursor = date_cursor.next_month.beginning_of_month
      end
    end

    def generate_indonesian_major_purchases!
      # Motor purchase
      motor_date = 2.years.ago.to_date
      down_payment = 2_000_000 # 2 million IDR down payment
      motor_loan = 8_000_000 # 8 million IDR motor loan

      create_transaction!(@bca_checking, down_payment, "DP Motor", @transportation_cat, motor_date)
      # Origination: move proceeds from loan liability to checking as a single transfer
      create_transfer!(@motor_loan, @bca_checking, motor_loan, "Motor Loan Proceeds", motor_date)

      # Personal loans (pinjam dari orang) - initial borrowing
      family_loan_date = 3.years.ago.to_date
      create_transaction!(@bca_checking, 5_000_000, "Pinjaman dari Ibu", @family_support_cat, family_loan_date)
      create_transaction!(@loan_from_family, 5_000_000, "Pinjaman dari Ibu", @family_support_cat, family_loan_date)

      friend_loan_date = 2.years.ago.to_date
      create_transaction!(@bca_checking, 3_000_000, "Pinjaman dari Teman", @family_support_cat, friend_loan_date)
      create_transaction!(@loan_from_friend, 3_000_000, "Pinjaman dari Teman", @family_support_cat, friend_loan_date)

      # Gold investment
      gold_date = 1.year.ago.to_date
      create_transaction!(@bca_checking, 3_000_000, "Beli Emas", @investment_income_cat, gold_date)
      create_transfer!(@bca_checking, @gold_investment, 3_000_000, "Investasi Emas", gold_date)
    end

    def generate_indonesian_transfers_and_payments!
      # Credit card payments
      date_cursor = 12.months.ago.beginning_of_month
      while date_cursor <= Date.current
        payment_date = first_business_day(date_cursor) + 15.days

        # Credit card payments
        if rand > 0.2
          cc_amount = 2_000_000
          create_transfer!(@bca_checking, @bca_credit, cc_amount, "Pembayaran Credit Card", payment_date)
        end

        date_cursor = date_cursor.next_month.beginning_of_month
      end
    end

    def generate_indonesian_regular_expenses!
      # Zakat and religious obligations
      date_cursor = 12.months.ago.beginning_of_month
      while date_cursor <= Date.current
        # Zakat Fitrah (during Ramadan)
        if date_cursor.month == 4 # April (approximate Ramadan)
          create_transaction!(@bca_checking, 50_000, "Zakat Fitrah", @zakat_cat, date_cursor)
        end

        # Monthly infaq
        if rand > 0.3
          create_transaction!(@bca_checking, 100_000, "Infaq Masjid", @infaq_cat, date_cursor)
        end

        date_cursor = date_cursor.next_month.beginning_of_month
      end
    end

    def generate_indonesian_legacy_transactions!
      # Historical transactions for better balance reconciliation
      legacy_date = 5.years.ago.to_date
      create_transaction!(@bca_checking, 10_000_000, "Setoran Awal", @salary_cat, legacy_date)
    end

    def generate_indonesian_crypto_and_misc_assets!
      # Bitcoin investment
      crypto_date = 2.years.ago.to_date
      create_transaction!(@bca_checking, 5_000_000, "Beli Bitcoin", @investment_income_cat, crypto_date)
      create_transfer!(@bca_checking, @indodax_btc, 5_000_000, "Investasi Bitcoin", crypto_date)
    end

    # Helper method to make loan payments with IDR amounts
    def make_loan_payment!(principal_account:, principal_amount:, interest_amount:, interest_category:, date:, memo:)
      # Principal portion – transfer from BCA checking to loan account
      create_transfer!(@bca_checking, principal_account, principal_amount, memo, date)

      # Interest portion – expense from BCA checking
      if interest_amount.positive?
        create_transaction!(@bca_checking, interest_amount, "#{memo} Interest", interest_category, date)
      end
    end

    # Override reconcile_balances! to use Indonesian accounts
    def reconcile_balances!(family)
      set_current_anchor!(@honda_civic, 120_000_000)
      set_current_anchor!(@yamaha_motor, 15_000_000)
      set_current_anchor!(@gold_investment, 4_500_000)
      set_current_anchor!(@indodax_btc, 2_000_000)
    end

    def set_current_anchor!(account, amount)
      date = Date.current
      name = Valuation.build_current_anchor_name(account.accountable_type)

      # Remove any existing valuation on the same date to satisfy uniqueness
      existing = account.entries.where(entryable_type: "Valuation", date: date)
      existing.destroy_all if existing.exists?

      account.entries.create!(
        entryable: Valuation.new(kind: "current_anchor"),
        amount: amount,
        name: name,
        currency: account.currency,
        date: date
      )
    end
end
