# Preview all emails at http://localhost:3000/rails/mailers/course_subscription_mailer
class CourseSubscriptionMailerPreview < ActionMailer::Preview

  def subscription_confirmation
    course = Course.first

    CourseSubscriptionMailer.subscription_confirmation(
      "test@example.com",
      course,
      "sample-token-123"
    )
  end

  def unsubscription_confirmation
    course = Course.first

    CourseSubscriptionMailer.subscription_confirmation(
      "test@example.com",
      course,
      "sample-token-123"
    )

  end
end
