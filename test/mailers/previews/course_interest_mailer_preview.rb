# Preview all emails at http://localhost:3000/rails/mailers/course_interest_mailer
class CourseInterestMailerPreview < ActionMailer::Preview

  def announce_event
    @event = Event.where.not(course: nil).first
    raise "No event found for preview" unless @event
    CourseInterestMailer.announce_event(@event, 'someone@somewhere.com', "this is a token")
  end

end
