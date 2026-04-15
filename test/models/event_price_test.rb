# test/models/event_price_test.rb
require "test_helper"

class EventPriceTest < ActiveSupport::TestCase
  setup do
    @event = events(:one)

    @mandatory = {
      event: @event,
      cost: 50,
      currency: "SEK",
      audience_type: "academic"
    }
  end

  test "should be valid with valid attributes" do
    price = EventPrice.new(@mandatory)
    assert price.valid?
  end

  test "should require cost" do
    price = EventPrice.new(@mandatory.merge(cost: nil))
    assert_not price.valid?
    assert_includes price.errors[:cost], "can't be blank"
  end

  test "should require non-negative cost" do
    price = EventPrice.new(@mandatory.merge(cost: -10))
    assert_not price.valid?
    assert_includes price.errors[:cost], "must be greater than or equal to 0"
  end

  test "should require currency" do
    price = EventPrice.new(@mandatory.merge(currency: nil))
    assert_not price.valid?
    assert_includes price.errors[:currency], "can't be blank"
  end

  test "should require audience_type" do
    price = EventPrice.new(@mandatory.merge(audience_type: nil))
    assert_not price.valid?
    assert_includes price.errors[:audience_type], "can't be blank"
  end

  test "should normalize audience_type before save" do
    price = EventPrice.new(@mandatory.merge(audience_type: "  Academic  "))
    price.save
    assert_equal "academic", price.audience_type
  end

  # Association tests
  test "should belong to event" do
    price = EventPrice.new(@mandatory.merge(event: nil))
    assert_not price.valid?
  end

  test "event responds to event_prices method" do
    assert_respond_to @event, :event_prices
  end

  test "event should have many event_prices" do
    @event.event_prices.destroy_all # remove fixture records

    @event.event_prices.create!(cost: 10, currency: "SEK", audience_type: "academic")
    @event.event_prices.create!(cost: 20, currency: "SEK", audience_type: "non-academic")

    assert_equal 2, @event.event_prices.count
  end

  test "destroying event should destroy associated event_prices" do
    @event.event_prices.destroy_all # remove fixture records
    @event.event_prices.create!(cost: 10, currency: "SEK", audience_type: "academic")

    assert_difference("EventPrice.count", -1) do
      @event.destroy
    end
  end

  test "should reject nested attributes with blank cost" do
    @event.event_prices.destroy_all # remove fixture records

    assert_no_difference("EventPrice.count") do
      @event.update(
        event_prices_attributes: [
          { cost: "", currency: "SEK", audience_type: "academic" }
        ]
      )
    end
  end

  test "should accept nested attributes with cost present" do
    @event.event_prices.destroy_all # remove fixture records

    assert_difference("EventPrice.count", 1) do
      @event.update(
        event_prices_attributes: [
          { cost: 100, currency: "SEK", audience_type: "academic" }
        ]
      )
    end
  end
end
