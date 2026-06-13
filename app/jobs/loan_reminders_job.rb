class LoanRemindersJob < ApplicationJob
  queue_as :scheduled

  def perform
    return unless LoanConfigurationService.feature_enabled?(:notifications)

    Loan.find_each do |loan|
      begin
        notifications = loan.check_and_send_reminders
        next if notifications.blank?

        # Instrument notifications for observability; actual channel dispatch can be plugged here.
        notifications.each do |note|
          ActiveSupport::Notifications.instrument(
            "sure.loan.notification",
            loan_id: loan.id,
            account_id: loan.account_id,
            title: note[:title],
            priority: note[:priority],
            action_url: note[:action_url],
            icon: note[:icon]
          )
        end
      rescue => e
        Rails.logger.error({ at: "LoanRemindersJob.error", loan_id: loan.id, error: e.message }.to_json) rescue nil
      end
    end
  end
end
