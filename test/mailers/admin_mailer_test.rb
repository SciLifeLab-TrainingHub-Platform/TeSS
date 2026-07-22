require "test_helper"

class AdminMailerTest < ActionMailer::TestCase
  test "review_event_test" do
    event = events(:one)
    mail = AdminMailer.review_event(event)

    # Test the recipient of the email
    assert_equal [AdminMailer::ADMIN_EMAIL_ADDRESS], mail.to

    # Test the subject of the email
    assert_equal "Event review for #{event.title}", mail.subject

    assert_emails 1 do
      mail.deliver_now
    end

    # Test that event attributes are in the email body
    assert_match event.id.to_s, mail.body.encoded
    assert_match event.title, mail.body.encoded
    assert_match event.url, mail.body.encoded
    assert_match event.user.username, mail.body.encoded
    assert_match event.user.email, mail.body.encoded
  end

  test "event_updated_by_user" do
    event = events(:one)
    mail = AdminMailer.event_updated_by_user(event)

    # Test the recipient of the email
    assert_equal [AdminMailer::ADMIN_EMAIL_ADDRESS], mail.to

    # Test the subject of the email
    assert_equal "Event #{event.title} updated by #{event.user.username}", mail.subject

    assert_emails 1 do
      mail.deliver_now
    end

    # Test that event attributes are in the email body
    assert_match event.id.to_s, mail.body.encoded
    assert_match event.title, mail.body.encoded
    assert_match event.url, mail.body.encoded
    assert_match event.user.username, mail.body.encoded
    assert_match event.user.email, mail.body.encoded
  end

  test "review_course email" do
    #   write test for this in the end
  end

  test "course_updated_by_user test" do
    #   write test for this in the end
  end
end
