require 'test_helper'

class EventsHelperTest < ActionView::TestCase
  setup do
    @user = users(:regular_user)
    @event_with_user = events(:one)
    @event_parameters = { start: @event_with_user.start, end: @event_with_user.end,
                          timezone: @event_with_user.timezone, contact: @event_with_user.contact, eligibility: @event_with_user.eligibility,
                          host_institutions: @event_with_user.host_institutions, nodes: @event_with_user.nodes,
                          language: @event_with_user.language, prerequisites: @event_with_user.prerequisites,
                          target_audience: @event_with_user.target_audience, content_providers: @event_with_user.content_providers,
                          learning_objectives: @event_with_user.learning_objectives,
                          event_prices_attributes: [{ cost: 9.99, currency: "SEK", audience_type: "Academic" }] }
  end

  test "neatly_printed_date_range" do
    assert_equal '15 April 2023',
                 neatly_printed_date_range(DateTime.new(2023, 4, 15, 0)),
                 'Should display single date without time if time is midnight'

    assert_equal '15 April 2023',
                 neatly_printed_date_range(DateTime.new(2023, 4, 15, 0), DateTime.new(2023, 4, 15, 0)),
                 'Should display single date without time if time is midnight'

    # assert_equal '15 April 2023 @ 09:00',
    #              neatly_printed_date_range(DateTime.new(2023, 4, 15, 9)),
    #              'Should display single date with single time if no finish date'

    assert_equal '15 April 2023 @ 09:00',
                 neatly_printed_date_range(DateTime.new(2023, 4, 15, 9), DateTime.new(2023, 4, 15, 9)),
                 'Should display single date with single time if both start and finish are the same'

    assert_equal '15 April 2023 @ 09:00 - 17:00',
                 neatly_printed_date_range(DateTime.new(2023, 4, 15, 9), DateTime.new(2023, 4, 15, 17)),
                 'Should display single date with time range'

    assert_equal '15 April 2023 @ 00:00 - 00:15',
                 neatly_printed_date_range(DateTime.new(2023, 4, 15, 0, 0), DateTime.new(2023, 4, 15, 0, 15)),
                 'Should display single date with time range if at least one time is not midnight'

    assert_equal '15 April 2023 @ 09:15 - 09:16',
                 neatly_printed_date_range(DateTime.new(2023, 4, 15, 9, 15), DateTime.new(2023, 4, 15, 9, 16)),
                 'Should display single date with time range'

    assert_equal '15 April 2023 @ 09:15 - 21:15',
                 neatly_printed_date_range(DateTime.new(2023, 4, 15, 9, 15), DateTime.new(2023, 4, 15, 21, 15)),
                 'Should display single date with time range'

    assert_equal '15 - 16 April 2023',
                 neatly_printed_date_range(DateTime.new(2023, 4, 15, 9), DateTime.new(2023, 4, 16, 17)),
                 'Should display date range without time'

    assert_equal '15 April - 16 May 2023',
                 neatly_printed_date_range(DateTime.new(2023, 4, 15, 9), DateTime.new(2023, 5, 16, 17)),
                 'Should display date and month range without time'

    assert_equal '15 April 2023 - 16 May 2024',
                 neatly_printed_date_range(DateTime.new(2023, 4, 15, 9), DateTime.new(2024, 5, 16, 17)),
                 'Should display date, month and year range without time'

    assert_equal '15 April 2023 - 16 May 2024',
                 neatly_printed_date_range(DateTime.new(2023, 4, 15), DateTime.new(2024, 5, 16)),
                 'Should display date, month and year range without time'

    assert_equal 'No date given', neatly_printed_date_range('', '')
    assert_equal 'No date given', neatly_printed_date_range(nil, '')
    assert_equal 'No start date', neatly_printed_date_range(nil, DateTime.new(2024, 5, 16, 17))
  end

  test "returns default options if user has no prior events with event prices" do
    new_user = User.create({ username: 'new_user', password: '12345678', email: 'new_user@example.com', processing_consent: '1' })
    new_event = Event.new(@event_parameters.merge({ user: new_user }))

    expected = EventPrice::DEFAULT_AUDIENCE_TYPES
    assert_equal expected.sort, get_event_audience_types(new_user).sort
  end

  test "event_cost_value escapes custom audience_type content" do
    event = Event.new
    event.event_prices.build(cost: 10, currency: "SEK", audience_type: '<script>alert("xss")</script>')

    rendered = event_cost_value(event)

    assert_includes rendered, '10 SEK'
    assert_includes rendered, '&lt;'
    assert_includes rendered, '&gt;'
    assert_includes rendered, '&quot;'
    refute_includes rendered, '<script>alert("xss")</script>'
  end

  test "includes custom audience types from user's previous event prices" do
    new_event_price_audience_type = "vip-academic"
    new_user = User.create!({ username: 'new_user', password: '12345678', email: 'new_user@example.com', processing_consent: '1' })
    new_event = Event.create!(@event_parameters.merge(
                                {
                                  user: new_user,
                                  title: 'Good event',
                                  url: 'http://good-domain.example/event',
                                  description: 'event for does not block non-disallowed domain', online: true
                                }
                              ))

    EventPrice.create!(
      event: new_event,
      cost: 50,
      currency: "SEK",
      audience_type: new_event_price_audience_type
    )

    expected = (EventPrice::DEFAULT_AUDIENCE_TYPES + [new_event_price_audience_type]).uniq

    assert_equal expected.sort, get_event_audience_types(new_user).sort
  end

  test "merges multiple custom audience types without duplicates" do
    new_user = User.create!(
      username: 'new_user_2',
      password: '12345678',
      email: 'new_user_2@example.com',
      processing_consent: '1'
    )

    new_event = Event.create!(
      @event_parameters.merge(
        user: new_user,
        title: 'Multiple Custom Event',
        url: 'http://multiple.example/event',
        description: 'event description',
        online: true
      )
    )

    # Create multiple EventPrices for the same user/event
    types = %w[vip-academic special-non-academic vip-academic] # duplicate on purpose
    types.each do |aud_type|
      EventPrice.create!(
        event: new_event,
        cost: rand(10..100),
        currency: "SEK",
        audience_type: aud_type
      )
    end

    # Expected: defaults + unique custom types
    expected = (EventPrice::DEFAULT_AUDIENCE_TYPES + types).uniq
    assert_equal expected.sort, get_event_audience_types(new_user).sort
  end
end
