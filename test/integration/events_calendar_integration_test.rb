# frozen_string_literal: true

require 'test_helper'

# Server-side rendering of the events calendar.
#
# NOTE: this test does NOT execute JavaScript, so it cannot catch a broken
# browser-side calendar load. See test/system/events_calendar_system_test.rb
# for the headless-browser test that covers the AJAX path.
class EventsCalendarIntegrationTest < ActionDispatch::IntegrationTest
  test 'calendar page loads and renders event calendar' do
    freeze_time(Time.utc(2026, 5, 20, 12, 0, 0)) do
      event = Event.order(:id).first!
      event.update!(
        title: 'Calendar smoke event',
        url: 'http://example.com/calendar-smoke-event',
        user: users(:regular_user),
        content_providers: [content_providers(:goblet)],
        timezone: 'UTC',
        language: 'en',
        prerequisites: 'None.',
        target_audience: ['Everyone!'],
        learning_objectives: 'Confirm the calendar renders.',
        start: Time.now.utc.beginning_of_month + 10.days,
        end: Time.now.utc.beginning_of_month + 10.days + 2.hours
      )

      get calendar_events_path

      assert_response :success
      assert_select '#events-calendar #calendar.simple-calendar'
      assert_select '#events-calendar table.table.table-striped'
      assert_select '#events-calendar a.clear-both', text: 'Calendar smoke event'
    end
  end
end
