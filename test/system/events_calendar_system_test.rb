# frozen_string_literal: true

require 'application_system_test_case'

# Headless-browser coverage for the events calendar.
#
# This is the test that catches a broken browser-side calendar load. The calendar
# tab fetches /events/calendar over AJAX and Rails executes the returned script,
# so it only renders if the bundled jQuery is the version the rest of the app
# expects. A server-side integration test cannot detect that.
class EventsCalendarSystemTest < ApplicationSystemTestCase
  test 'calendar tab loads and renders events with javascript' do
    freeze_time(Time.utc(2026, 5, 20, 12, 0, 0)) do
      Event.order(:id).first!.update!(
        title: 'System calendar event',
        url: 'http://example.com/system-calendar-event',
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

      visit events_path

      within('.index-display-options') { click_link 'Calendar' }

      assert_selector('#events_calendar #calendar.simple-calendar')
      assert_selector('#events_calendar a.clear-both', text: 'System calendar event')
    end
  end
end
