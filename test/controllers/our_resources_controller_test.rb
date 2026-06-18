require 'test_helper'

class OurResourcesControllerTest < ActionController::TestCase
  include Devise::Test::ControllerHelpers

  test 'should get resources landing page' do
    get :our_resources

    assert_response :success
    assert_select 'h1', 'Where do you find yourself?'
    assert_select '.resources-lifecycle__card', count: 4
    assert_select '.resources-lifecycle__card h2', text: 'Design & Develop'
    assert_select '.resources-lifecycle__card h2', text: 'Plan'
    assert_select '.resources-lifecycle__card h2', text: 'Deliver'
    assert_select '.resources-lifecycle__card h2', text: 'Evaluate & Archive'
    assert_select '.resources-lifecycle__card[href=?]', design_develop_path, count: 1
  end

  test 'should get design develop page' do
    get :design_develop

    assert_response :success
    assert_select 'h1', 'Design & Develop'
    assert_select '.resources-stage-resource', count: 6
    assert_select '.resources-stage-page__section h2', text: /Identify your Target Audience/
    assert_select 'img[alt=?]', 'Presenter and participants interaction diagram'
    assert_select '.resources-stage-contributors__item', text: /Oliver Onions/
    assert_select '.resources-stage-contributors__item', text: /Ineke Luijten/
  end
end
