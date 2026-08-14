require 'test_helper'

class ResourcesTest < ActionDispatch::IntegrationTest
  test 'canonical resources pages render' do
    [
      resources_path,
      plan_design_stage_path,
      develop_stage_path,
      deliver_stage_path,
      evaluate_archive_stage_path
    ].each do |path|
      get path

      assert_response :success, "Expected #{path} to render successfully"
    end
  end

  test 'legacy resources URLs redirect permanently' do
    {
      '/our_resources' => resources_path,
      '/our_resources/guides' => resources_path,
      '/our_resources/pedagogic_support' => resources_path(anchor: 'resources-consultation-title'),
      '/our_resources/trainer_community' => resources_path,
      '/our_resources/fair_training' => develop_stage_path(anchor: 'fair-training-materials')
    }.each do |legacy_path, destination|
      get legacy_path

      assert_response :moved_permanently
      assert_redirected_to destination
    end
  end

  test 'landing page exposes the booking calendar contract' do
    get resources_path

    assert_response :success
    assert_select '[data-cal-embed]' \
                  '[data-cal-namespace="support-consult"]' \
                  '[data-cal-link="scilifelab-traininghub/support-consult"]',
                  count: 1
    assert_select '[data-cal-calendar][hidden]', count: 1
    assert_select '[data-cal-status][role="status"][aria-live="polite"]', count: 1 do |statuses|
      status = statuses.first

      assert status['data-loading-message'].present?
      assert status['data-failure-message'].present?
    end
    assert_select '[data-cal-fallback]', count: 1 do |fallbacks|
      assert_nil fallbacks.first['hidden']
      assert_select 'a[href=?][target=?][rel=?]',
                    'https://cal.com/scilifelab-traininghub/support-consult',
                    '_blank',
                    'noopener noreferrer',
                    count: 1
    end
  end

  test 'stage page renders a canonical YouTube embed' do
    get plan_design_stage_path

    assert_response :success
    assert_select '.resources-stage-video iframe[src=?][loading="lazy"][title]',
                  'https://www.youtube.com/embed/IWDtFrMD298',
                  count: 1
  end
end
