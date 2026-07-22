# Preview all emails at http://localhost:3000/rails/mailers/user_mailer
class UserMailerPreview < ActionMailer::Preview
  def event_published
    @event = Event.first
    UserMailer.event_published(@event)
  end

  def event_submitted
    @event = Event.first
    UserMailer.event_submitted(@event)
  end

  def course_published
    course = Course.first
    UserMailer.course_published(course)
  end

  def course_submitted
    course = Course.first
    UserMailer.course_submitted(course)
  end
end
