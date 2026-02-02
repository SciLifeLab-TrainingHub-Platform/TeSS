require "test_helper"

class CitiesControllerTest  < ActionController::TestCase
  include Devise::Test::ControllerHelpers

  setup do
    sign_in users(:regular_user)
    @city_1 = City.create!(name: "Stockholm", country_code: "SE")
    @city_2 = City.create!(name: "Gothenburg", country_code: "SE")
    @city_3 = City.create!(name: "Oslo", country_code: "NO")
    @city_4 = City.create!(name: "London", country_code: "GB")
    @online_city = City.find_or_create_by!(name: City::ONLINE_CITY, country_code: nil)
  end

  test "should return 400 when country_code is missing" do
    post :cities_by_country, params: {}, as: :json
    assert_response :bad_request
    response_body = JSON.parse(response.body)
    assert_equal "Country code is required", response_body["error"]
  end

  test "should return 200 with cities when country_code is valid" do
    post :cities_by_country, params: { country_code: "SE" }, as: :json
    assert_response :success

    response_body = JSON.parse(response.body)
    assert_equal 3, response_body["cities"].length
    assert_includes response_body["cities"], { "id" => @city_1.id, "name" => "Stockholm" }
    assert_includes response_body["cities"], { "id" => @city_2.id, "name" => "Gothenburg" }
    assert_includes response_body["cities"], { "id" => @online_city.id, "name" => City::ONLINE_CITY }
    assert_not_includes response_body["cities"], { "id" => @city_3.id, "name" => "Oslo" }

    post :cities_by_country, params: { country_code: "GB" }, as: :json
    assert_response :success

    response_body = JSON.parse(response.body)
    assert_equal 2, response_body["cities"].length
    assert_includes response_body["cities"], { "id" => @city_4.id, "name" => "London" }
    assert_includes response_body["cities"], { "id" => @online_city.id, "name" => City::ONLINE_CITY }
  end

  test "should return 200 when no cities are found for country_code" do
    post :cities_by_country, params: { country_code: "US" }, as: :json
    assert_response :success

    response_body = JSON.parse(response.body)
    assert_equal 1, response_body["cities"].length
    assert_includes response_body["cities"], { "id" => @online_city.id, "name" => City::ONLINE_CITY }
  end

end
