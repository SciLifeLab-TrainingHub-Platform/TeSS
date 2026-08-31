# frozen_string_literal: true

require 'test_helper'

class StaticHelperTest < ActionView::TestCase
  test 'formats a homepage event date range in the same month' do
    event = Event.new(
      start: Time.zone.local(2026, 8, 17),
      end: Time.zone.local(2026, 8, 28)
    )

    assert_equal 'August 17-28, 2026', homepage_event_date_range(event)
    assert_equal 'August 17 - 28, 2026', homepage_event_date_range(event, range_separator: ' - ')
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

  test 'formats an open homepage training application deadline' do
    event = Event.new(application_deadline: 1.week.from_now)

    assert_match(/\AApply by: [A-Z][a-z]{2} \d{1,2}, \d{4}\z/, homepage_training_registration_label(event))
  end

  test 'marks a passed homepage training application deadline as closed' do
    event = Event.new(application_deadline: 1.minute.ago)

    assert_equal 'Registration closed', homepage_training_registration_label(event)
  end

  test 'omits a homepage training registration label without a deadline' do
    assert_nil homepage_training_registration_label(Event.new)
  end

  test 'uses delivery and location data for homepage training tags' do
    event = Event.new(presence: :onsite, country: 'Sweden')

    assert_equal 'In person', homepage_training_delivery_label(event)
    assert_equal ['Sweden'], homepage_training_locations(event)
  end

  test 'omits locations for online homepage training' do
    event = Event.new(presence: :online, country: 'Sweden')

    assert_equal 'Online', homepage_training_delivery_label(event)
    assert_empty homepage_training_locations(event)
  end

  test 'shows every homepage training location when the card tag limit is not exceeded' do
    event = Event.new(presence: :onsite)
    %w[Gothenburg Linköping Lund].each { |name| event.cities.build(name:) }

    tags = homepage_training_location_tags(event, delivery_present: true)

    assert_equal %w[Gothenburg Linköping Lund], tags
  end

  test 'reserves the final homepage training tag for an overflow summary' do
    event = Event.new(presence: :onsite)
    %w[Gothenburg Linköping Lund Stockholm Kiruna Malmö Umeå Kalmar].each do |name|
      event.cities.build(name:)
    end

    tags = homepage_training_location_tags(event, delivery_present: true)

    assert_equal ['Gothenburg', 'Linköping', '+6 more'], tags
  end

  test 'uses every homepage training tag slot when there is no delivery tag' do
    event = Event.new
    %w[Gothenburg Linköping Lund Stockholm].each { |name| event.cities.build(name:) }

    tags = homepage_training_location_tags(event, delivery_present: false)

    assert_equal %w[Gothenburg Linköping Lund Stockholm], tags
  end
end
