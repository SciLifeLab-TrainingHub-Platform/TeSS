require "test_helper"

class TopicTest < ActiveSupport::TestCase

  setup do
    @topic = Topic.new(name: "DevOps")
    @topic_one = topics(:one)
    @topic_two = topics(:two)
    @event_one = events(:one)
    @event_two = events(:two)
    @mandatory = { start: Date.today, end: Date.today + 1.day }

  end

  test "should be valid with valid attributes" do
    assert @topic.valid?
  end

  test "should add event to topic" do
    parameters = @mandatory.merge({ user: users(:regular_user), title: 'New event', url: 'http://example.com',
                                    online: false, description: 'A new event',
                                    country: 'UK', postcode: 'M16 0TH' })
    new_event = Event.create(parameters)
    @topic_one.events << new_event
    assert_includes @topic_one.events, new_event
  end

  test "should remove event from topic" do
    @topic_one.events.delete(@event_one)
    assert_not_includes @topic_one.events, @event_one
  end

  test "should destroy topic and keep event" do
    @topic_two.destroy
    assert Event.exists?(@event_two.id)
  end
end
