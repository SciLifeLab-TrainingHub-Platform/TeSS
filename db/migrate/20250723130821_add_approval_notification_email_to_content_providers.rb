class AddApprovalNotificationEmailToContentProviders < ActiveRecord::Migration[7.0]
  def change
    add_column :content_providers, :approval_notification_email, :string
  end
end
