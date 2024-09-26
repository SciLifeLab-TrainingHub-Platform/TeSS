require "test_helper"

class CityTest < ActiveSupport::TestCase
  setup do
    @event_one = events(:one)
    @event_two = events(:two)
    @city_one = cities(:one)
    @city_two = cities(:two)

    @mandatory = { start: @event_one.start, end: @event_one.end,
                   timezone: @event_one.timezone, contact: @event_one.contact, eligibility: @event_one.eligibility,
                   host_institutions: @event_one.host_institutions }

  end

  test "should have events" do
    assert_equal 1, @city_one.events.count
    assert_equal @event_one, @city_one.events.first

    assert_equal 1, @city_two.events.count
    assert_equal @event_two, @city_two.events.first
  end

  test "should add event to city" do
    parameters = @mandatory.merge({ user: users(:regular_user), title: 'New event', url: 'http://example.com',
                                    online: false, description: 'A new event',
                                    country: 'UK', postcode: 'M16 0TH' })
    new_event = Event.create(parameters)
    @city_one.events << new_event
    assert_includes @city_one.events, new_event
  end

  test "should remove event from city" do
    @city_one.events.delete(@event_one)
    assert_not_includes @city_one.events, @event_one
  end

  test "should destroy city and keep event" do
    @city_two.destroy
    assert Event.exists?(@event_two.id)
  end
end
