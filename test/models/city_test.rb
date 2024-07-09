require "test_helper"

class CityTest < ActiveSupport::TestCase
  setup do
    @event_one = events(:one)
    @event_two = events(:two)
    @city_one = cities(:one)
    @city_two = cities(:two)
  end

  test "should have events" do
    assert_equal 1, @city_one.events.count
    assert_equal @event_one, @city_one.events.first

    assert_equal 1, @city_two.events.count
    assert_equal @event_two, @city_two.events.first
  end

  test "should add event to city" do
    new_event = Event.create(title: "New Event", url: "http://example.com/new-event", description: "A new event")
    @city_one.events << new_event
    assert_includes @city_one.events, new_event
  end

  test "should remove event from city" do
    @city_one.events.delete(@event_one)
    assert_not_includes @city_one.events, @event_one
  end

  test "should destroy city and keep event" do
    @city_one.destroy
    assert Event.exists?(@event_one.id)
  end
end
