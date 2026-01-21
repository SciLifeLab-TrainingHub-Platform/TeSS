class ApprovalLifecycle
  def initialize(record, notifier:)
    @record   = record
    @user     = record.user
    @notifier = notifier
  end

  # Call on creation
  def after_create
    if @user.admin_or_trusted?
      @notifier.publish
    else
      @notifier.review
    end
  end

  def after_status_change
    @user.approve_event!
    @notifier.publish
  end
end
