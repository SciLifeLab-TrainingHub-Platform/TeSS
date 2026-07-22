# frozen_string_literal: true

require 'test_helper'

class ContentProviderMailerTest < ActionMailer::TestCase
  test "event_content_provider_notification" do
    event = events(:one)
    content_provider = content_providers(:approval_notification_email_contact_provider)

    mail = ContentProviderMailer.event_content_provider_notification(event, content_provider)

    # Test the recipient of the email
    assert_equal [content_provider.approval_notification_email], mail.to

    # Test the subject of the email
    assert_equal "New event ‘#{event.title}’ submitted with your content provider ‘#{content_provider.title}’", mail.subject

    # Test that exactly one email is sent
    assert_emails 1 do
      mail.deliver_now
    end

    assert_match event.title, mail.body.encoded
    assert_match event.start.strftime('%B %d, %Y'), mail.body.encoded
    assert_match event.venue, mail.body.encoded
    assert_match event.user.name, mail.body.encoded
    assert_match event.user.email, mail.body.encoded
    assert_match content_provider.approval_notification_email, mail.body.encoded
  end

  test "does not send email for event if approval_notification_email is blank" do
    event = events(:one)
    content_provider = content_providers(:no_approval_notification_email_contact_provider)
    mail = ContentProviderMailer.event_content_provider_notification(event, content_provider)

    assert_no_emails do
      mail.deliver_now
    end
  end

  test "course_content_provider_notification" do
    course = courses(:one)
    content_provider = content_providers(:approval_notification_email_contact_provider)

    mail = ContentProviderMailer.course_content_provider_notification(course, content_provider)

    # Test the recipient of the email
    assert_equal [content_provider.approval_notification_email], mail.to

    # Test the subject of the email
    assert_equal(
      "New course ‘#{course.title}’ submitted for ‘#{content_provider.title}’",
      mail.subject
    )

    # Test that exactly one email is sent
    assert_emails 1 do
      mail.deliver_now
    end

    # Test email body contents
    assert_match course.title, mail.body.encoded
    assert_match content_provider.title, mail.body.encoded
    assert_match content_provider.approval_notification_email, mail.body.encoded
  end

  test "does not send email for course if approval_notification_email is blank" do
    course = courses(:one)
    content_provider = content_providers(:no_approval_notification_email_contact_provider)

    mail = ContentProviderMailer.course_content_provider_notification(course, content_provider)

    assert_no_emails do
      mail.deliver_now
    end
  end
end
