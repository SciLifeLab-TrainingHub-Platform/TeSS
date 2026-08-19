require 'test_helper'

class StaticHelperTest < ActionView::TestCase
  test 'formats a homepage event date range in the same month' do
    event = Event.new(
      start: Time.zone.local(2026, 8, 17),
      end: Time.zone.local(2026, 8, 28)
    )

    assert_equal 'August 17-28, 2026', homepage_event_date_range(event)
  end

  test 'formats a homepage event date range across months' do
    event = Event.new(
      start: Time.zone.local(2026, 8, 30),
      end: Time.zone.local(2026, 9, 2)
    )

    assert_equal 'August 30-September 2, 2026', homepage_event_date_range(event)
  end

  test 'formats a single homepage event date' do
    event = Event.new(start: Time.zone.local(2026, 8, 17))

    assert_equal 'August 17, 2026', homepage_event_date_range(event)
  end
end
