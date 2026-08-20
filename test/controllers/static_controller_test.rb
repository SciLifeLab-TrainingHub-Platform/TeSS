require 'test_helper'

class StaticControllerTest < ActionController::TestCase
  include Devise::Test::ControllerHelpers

  test 'should get home' do
    get :home
    assert_response :success
  end

  test 'selects the newest upcoming event as featured and excludes it from the next four events' do
    selected_events = Event.order(:id).first(6)
    base_time = 2.weeks.from_now

    selected_events.each_with_index do |event, index|
      event.update_columns(
        start: base_time + index.days,
        end: base_time + index.days + 2.hours,
        created_at: base_time - (5 - index).hours
      )
    end

    @controller.stub(:homepage_event_scope, Event.where(id: selected_events.map(&:id))) do
      get :home
    end

    homepage = @controller.view_assigns

    assert_equal selected_events.last, homepage['featured_event']
    assert_equal selected_events.first(4), homepage['upcoming_training_events'].to_a
    refute_includes homepage['upcoming_training_events'], homepage['featured_event']
  end

  test 'uses only publicly available current and upcoming events on the homepage' do
    eligible, hidden, unapproved, expired, failing = Event.order(:id).first(5)
    candidates = [eligible, hidden, unapproved, expired, failing]
    starts_at = 2.weeks.from_now

    candidates.each do |event|
      event.update_columns(
        start: starts_at,
        end: starts_at + 2.hours,
        event_status: Event.event_statuses[:approved],
        visible: true
      )
    end

    hidden.update_columns(visible: false)
    unapproved.update_columns(event_status: Event.event_statuses[:awaiting_review])
    expired.update_columns(start: 2.days.ago, end: 1.day.ago)
    failing.create_link_monitor!(url: failing.url, fail_count: LinkMonitor::FAILURE_THRESHOLD)

    homepage_events = @controller
                      .send(:homepage_event_scope)
                      .where(id: candidates.map(&:id))
                      .to_a

    assert_equal [eligible], homepage_events
  end

  test 'handles a homepage without upcoming events' do
    @controller.stub(:homepage_event_scope, Event.none) do
      get :home
    end

    homepage = @controller.view_assigns

    assert_nil homepage['featured_event']
    assert_empty homepage['upcoming_training_events']
  end

  test 'counts only providers belonging to public users' do
    public_providers = ContentProvider.from_verified_users
    public_count = public_providers.count
    provider_to_hide = content_providers(:goblet)

    assert_includes public_providers, provider_to_hide

    provider_to_hide.update_columns(user_id: users(:unverified_user).id)

    get :home

    assert_equal public_count - 1, @controller.view_assigns['provider_count']
  end

  test 'should show tabs for enabled features' do
    skip 'Skipping this test as we are no longer maintaining UI test cases'

    features = { 'events': true,
                 'materials': true,
                 'elearning_materials': true,
                 'workflows': true,
                 'collections': true,
                 'content_providers': true,
                 'trainers': true,
                 'nodes': true }

    with_settings(feature: features) do
      get :home
    end

    # skipping as we are no longer maintaining the UI test cases
    assert_select 'ul.nav.navbar-nav' do
      assert_select 'li a[href=?]', about_path
      assert_select 'li a[href=?]', events_path
      assert_select 'li a[href=?]', materials_path
      assert_select 'li a[href=?]', workflows_path
      assert_select 'li a[href=?]', elearning_materials_path
      assert_select 'li a[href=?]', collections_path
      assert_select 'li.dropdown.directory-menu' do
        assert_select 'li a[href=?]', content_providers_path
        assert_select 'li a[href=?]', trainers_path
        assert_select 'li a[href=?]', nodes_path
      end
    end
  end

  test 'should not show tabs for disabled features' do
    skip 'Skipping this test as we are no longer maintaining UI test cases'

    features = { 'events': false,
                 'materials': false,
                 'elearning_materials': false,
                 'workflows': false,
                 'collections': false,
                 'content_providers': false,
                 'trainers': false,
                 'nodes': false }

    with_settings(feature: features) do
      get :home
    end

    assert_select 'ul.nav.navbar-nav' do
      assert_select 'li a[href=?]', about_path
      assert_select 'li a[href=?]', events_path, count: 0
      assert_select 'li a[href=?]', materials_path, count: 0
      assert_select 'li a[href=?]', workflows_path, count: 0
      assert_select 'li a[href=?]', elearning_materials_path, count: 0
      assert_select 'li a[href=?]', collections_path, count: 0
      assert_select 'li a[href=?]', content_providers_path, count: 0
      assert_select 'li a[href=?]', trainers_path, count: 0
      assert_select 'li a[href=?]', nodes_path, count: 0
      assert_select 'li.dropdown.directory-menu', count: 0
    end
  end

  test 'should allow configuration of tab order and directory' do
    skip 'Skipping this test as we are no longer maintaining UI test cases'

    features = { 'events': true,
                 'materials': true,
                 'elearning_materials': true,
                 'workflows': true,
                 'collections': true,
                 'content_providers': true,
                 'trainers': true,
                 'nodes': true }

    with_settings(feature: features, site: { tab_order: %w[materials events], directory_tabs: [] }) do
      get :home
      assert_select 'ul.nav.navbar-nav' do
        assert_select 'li:nth-child(1) a[href=?]', materials_path
        assert_select 'li:nth-child(2) a[href=?]', events_path
        assert_select 'li a[href=?]', about_path
        assert_select 'li a[href=?]', workflows_path
        assert_select 'li a[href=?]', elearning_materials_path
        assert_select 'li a[href=?]', collections_path
        assert_select 'li a[href=?]', content_providers_path
        assert_select 'li a[href=?]', trainers_path
        assert_select 'li a[href=?]', nodes_path
        assert_select 'li.dropdown.directory-menu', count: 0
      end
    end

    with_settings(feature: features, site: { tab_order: %w[content_providers about materials trainers],
                                             directory_tabs: [] }) do
      get :home

      assert_select 'ul.nav.navbar-nav' do
        assert_select 'li:nth-child(1) a[href=?]', content_providers_path
        assert_select 'li:nth-child(2) a[href=?]', about_path
        assert_select 'li:nth-child(3) a[href=?]', materials_path
        assert_select 'li:nth-child(4) a[href=?]', trainers_path
        assert_select 'li a[href=?]', events_path
        assert_select 'li a[href=?]', workflows_path
        assert_select 'li a[href=?]', elearning_materials_path
        assert_select 'li a[href=?]', collections_path
        assert_select 'li a[href=?]', nodes_path
        assert_select 'li.dropdown.directory-menu', count: 0
      end
    end

    with_settings(feature: features, site: { tab_order: %w[content_providers about materials trainers],
                                             directory_tabs: %w[about materials] }) do
      get :home

      assert_select 'ul.nav.navbar-nav' do
        assert_select 'li:nth-child(1) a[href=?]', content_providers_path
        assert_select 'li:nth-child(2) a[href=?]', trainers_path
        assert_select 'li a[href=?]', events_path
        assert_select 'li a[href=?]', workflows_path
        assert_select 'li a[href=?]', elearning_materials_path
        assert_select 'li a[href=?]', collections_path
        assert_select 'li a[href=?]', nodes_path
        assert_select 'li.dropdown.directory-menu' do
          assert_select 'li:nth-child(1) a[href=?]', about_path
          assert_select 'li:nth-child(2) a[href=?]', materials_path
        end
      end
    end
  end

  test 'should not show registration button if disabled for country' do
    skip 'Skipping this test as we are no longer maintaining UI test cases'

    with_settings({ blocked_countries: ['gb'] }) do
      Locator.instance.stub(:lookup, { 'country' => { 'iso_code' => 'GB' } }) do
        get :home
        assert_response :success
        assert_select '.dropdown-item a', text: 'Register', count: 0
      end

      Locator.instance.stub(:lookup, { 'country' => { 'iso_code' => 'FR' } }) do
        get :home
        assert_response :success
        assert_select '.dropdown-item a', text: 'Register', count: 1
      end
    end
  end
end
