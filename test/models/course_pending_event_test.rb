# frozen_string_literal: true

require "test_helper"

class CoursePendingEventTest < ActiveSupport::TestCase
  test "is valid with a course and an event" do
    cpe = CoursePendingEvent.new(course: courses(:one), event: events(:one))

    assert cpe.valid?
  end

  test "requires course and event" do
    assert_not CoursePendingEvent.new(event: events(:one)).valid?
    assert_not CoursePendingEvent.new(course: courses(:one)).valid?
  end

  test "enforces event exclusivity (validation + DB constraint)" do
    CoursePendingEvent.create!(course: courses(:one), event: events(:one))

    dup = CoursePendingEvent.new(course: courses(:two), event: events(:one))
    assert_not dup.valid?
    assert_includes dup.errors[:event_id], "has already been taken"

    assert_raises(ActiveRecord::RecordNotUnique, ActiveRecord::StatementInvalid) do
      CoursePendingEvent.insert_all(
        [
          {
            course_id: courses(:two).id,
            event_id: events(:one).id,
            created_at: Time.current,
            updated_at: Time.current
          }
        ]
      )
    end
  end

  test "course destroy removes pending event rows" do
    course = courses(:one)
    event = events(:one)

    CoursePendingEvent.create!(course: course, event: event)

    assert_difference("CoursePendingEvent.count", -1) do
      course.destroy
    end
  end

  test "event delete cascades pending event rows" do
    course = courses(:one)

    event = Event.create!(
      title: "Pending event cleanup test",
      url: "https://example.com/pending-event-cleanup-test",
      description: "Test event",
      event_types: ["workshops_and_courses"],
      start: Time.zone.parse("2030-01-01 10:00:00"),
      end: Time.zone.parse("2030-01-01 12:00:00"),
      sponsors: [],
      keywords: [],
      user: users(:regular_user),
      host_institutions: [],
      contact: "Test contact",
      eligibility: ["first_come_first_served"],
      timezone: "UTC",
      duration: "00:00",
      learning_objectives: "None",
      recognition: "None",
      language: "en",
      prerequisites: "None",
      target_audience: ["Everyone"],
      cost_basis: "Free",
      registration_form_url: "https://example.com/registration",
      nodes: [nodes(:westeros)]
    )

    CoursePendingEvent.create!(course: course, event: event)
    assert_equal 1, CoursePendingEvent.where(event_id: event.id).count

    assert_difference("CoursePendingEvent.count", -1) do
      event.delete
    end
  end
end

