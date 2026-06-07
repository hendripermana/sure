require "test_helper"

class LoanHelperTest < ActionView::TestCase
  test "smart_loan_name_placeholder returns appropriate placeholder for personal loans" do
    placeholder = smart_loan_name_placeholder(true)
    assert_includes placeholder, "Ahmad"
    assert_includes placeholder, "Family loan"
  end

  test "smart_loan_name_placeholder returns appropriate placeholder for institutional loans" do
    placeholder = smart_loan_name_placeholder(false)
    assert_includes placeholder, "BCA"
    assert_includes placeholder, "Mortgage"
  end

  test "smart_interest_rate_default returns 0 for personal loans" do
    rate = smart_interest_rate_default(true, false)
    assert_equal 0, rate
  end

  test "smart_interest_rate_default returns 0 for sharia compliant loans" do
    rate = smart_interest_rate_default(false, true)
    assert_equal 0, rate
  end

  test "smart_interest_rate_default returns appropriate rate for institutional loans" do
    Current.stubs(:family).returns(OpenStruct.new(currency: "IDR"))

    assert_equal 12.0, smart_interest_rate_default(false, false)
  end

  test "smart_term_months_default returns shorter term for personal loans" do
    term = smart_term_months_default(true)
    assert_equal 12, term
  end

  test "smart_term_months_default returns longer term for institutional loans" do
    term = smart_term_months_default(false)
    assert_equal 24, term
  end

  test "loan_validation_message returns contextual message for personal loans" do
    message = loan_validation_message(:counterparty_name, :blank, "personal")
    assert_includes message, "lender's name"
  end

  test "loan_validation_message returns contextual message for institutional loans" do
    message = loan_validation_message(:counterparty_name, :blank, "institutional")
    assert_includes message, "institution name"
  end

  test "smart_loan_suggestion returns appropriate suggestion for personal loans" do
    suggestion = smart_loan_suggestion("personal", :counterparty_name)
    assert_includes suggestion, "Ahmad"
  end

  test "smart_loan_suggestion returns appropriate suggestion for institutional loans" do
    suggestion = smart_loan_suggestion("institutional", :counterparty_name)
    assert_includes suggestion, "Bank Mandiri"
  end

  test "loan_field_help_text returns contextual help for personal loans" do
    help_text = loan_field_help_text(:counterparty_name, "personal")
    assert_includes help_text, "person you're borrowing from"
  end

  test "loan_field_help_text returns contextual help for institutional loans" do
    help_text = loan_field_help_text(:counterparty_name, "institutional")
    assert_includes help_text, "bank or financial institution"
  end

  test "enhanced_validation_error returns properly formatted error message" do
    error_html = enhanced_validation_error(:initial_balance, :blank, "personal")
    assert_includes error_html, "error-message"
    assert_includes error_html, "Please enter the loan amount"
  end

  test "enhanced_success_message returns properly formatted success message" do
    success_html = enhanced_success_message("Loan created successfully")
    assert_includes success_html, "success-message"
    assert_includes success_html, "Loan created successfully"
  end

  test "smart_field_group_class returns appropriate class for personal loans" do
    css_class = smart_field_group_class("personal", "personal")
    assert_includes css_class, "field-group personal"
  end

  test "smart_field_group_class returns appropriate class for institutional loans" do
    css_class = smart_field_group_class("institutional", "institutional")
    assert_includes css_class, "field-group institutional"
  end

  test "enhanced_form_section returns properly structured section" do
    section_html = enhanced_form_section("Test Title", "Test Subtitle", 1)
    assert_includes section_html, "enhanced-form-section"
    assert_includes section_html, "Test Title"
    assert_includes section_html, "Test Subtitle"
  end
end
