require "test_helper"

class CourseInterestMailerTest < ActionMailer::TestCase

  def setup
    @course = courses(:one)
    @event = events(:course_interest_mail_event)
    @email = "someone@example.com"
  end

  test "announce_event sends email to given address" do
    mail = CourseInterestMailer.announce_event(@event, @email, "test-token")
    assert_emails 1 do
      mail.deliver_now
    end
    assert_equal [@email], mail.to
  end

  test "announce_event uses event from course relationship" do
    assert_equal @course, @event.course
    mail = CourseInterestMailer.announce_event(@event, @email, "test-token")
    assert mail.subject.present?
    assert_includes mail.body.encoded.downcase, @course.title.downcase
  end

  test "announce_event includes event name in body" do
    mail = CourseInterestMailer.announce_event(@event, @email, "test-token")
    assert_includes mail.body.encoded, @event.title
    assert_includes mail.body.encoded, "test-token"
  end

end
