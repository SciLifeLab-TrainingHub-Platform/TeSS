require "test_helper"

class UserMailerTest < ActionMailer::TestCase
  test "event_published_test" do
    event = events(:one)
    mail = UserMailer.event_published(event)

    # Test the recipient of the email
    assert_equal [event.user.email], mail.to

    # Test the subject of the email
    assert_equal "Your event '#{event.title}' has been successfully published", mail.subject

    assert_emails 1 do
      mail.deliver_now
    end

    # Test that event attributes are in the email body
    assert_match event.title, mail.body.encoded
    assert_match event.user.username, mail.body.encoded
  end

  test "event_submitted_test" do
    event = events(:one)
    mail = UserMailer.event_submitted(event)

    # Test the recipient of the email
    assert_equal [event.user.email], mail.to

    # Test the subject of the email
    assert_equal "Your event '#{event.title}' has been successfully submitted", mail.subject

    assert_emails 1 do
      mail.deliver_now
    end

    # Test that event attributes are in the email body
    assert_match event.title, mail.body.encoded
    assert_match event.url, mail.body.encoded
    assert_match event.user.username, mail.body.encoded
    assert_match event.start.strftime('%d %B %Y'), mail.body.encoded
    assert_match event.end.strftime('%d %B %Y'), mail.body.encoded
  end
end
