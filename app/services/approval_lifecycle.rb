class ApprovalLifecycle
  def initialize(record)
    @record = record
    @user = record.user
  end

  # Call on creation
  def after_create
    if @user.admin_or_trusted?
      send_publish_notifications
    else
      send_review_notifications
    end
  end

  # Call on status change
  def after_status_change
    @user.approve_event!
    send_publish_notifications
  end

  private

  def send_publish_notifications
    UserMailer.event_published(@record).deliver_later if @record.user.has_role?('trusted_user')
    @record.content_providers&.each do |cp|
      ContentProviderMailer.notify_content_provider(@record, cp).deliver_later
    end
  end

  def send_review_notifications
    AdminMailer.review_event(@record).deliver_later
    UserMailer.event_submitted(@record).deliver_later
  end

  def publishable?
    event.status_just_approved? &&
      event.start.present? &&
      event.start.to_datetime >= DateTime.current
  end
end

