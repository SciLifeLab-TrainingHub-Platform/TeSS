module OurResourcesHelper
  def resource_lifecycle_stages(active_key: nil)
    [
      { key: :plan_design, path: plan_design_stage_path },
      { key: :develop, path: develop_stage_path },
      { key: :deliver, path: deliver_stage_path },
      { key: :evaluate_archive, path: evaluate_archive_stage_path }
    ].map do |stage|
      lifecycle_locale_key = "our_resources.landing.lifecycle.stages.#{stage[:key]}"
      stage_page_locale_key = "our_resources.stage_pages.#{stage[:key]}"

      {
        timeframe: t("#{lifecycle_locale_key}.timeframe"),
        title: t("#{stage_page_locale_key}.title"),
        description: t("#{lifecycle_locale_key}.description"),
        path: stage[:path],
        active: stage[:key] == active_key
      }
    end
  end

  def stage_page_section_links(stage_key)
    sections = t(
      "our_resources.stage_pages.#{stage_key}.sections",
      default: {}
    ).with_indifferent_access

    sections.values.map do |section|
      {
        anchor: section[:anchor],
        title: section[:nav_title] || section[:title]
      }
    end
  end

  def stage_page_contributors(stage_key)
    contributor_profiles = t(
      'our_resources.stage_pages.contributor_profiles',
      default: {}
    ).with_indifferent_access
    contributor_keys = t(
      "our_resources.stage_pages.#{stage_key}.contributors",
      default: []
    )

    contributor_keys.map { |key| contributor_profiles.fetch(key) }
  end

  def stage_page_further_learning(stage_key)
    resource_profiles = t(
      'our_resources.stage_pages.learning_resource_profiles',
      default: {}
    ).with_indifferent_access
    resource_keys = t(
      "our_resources.stage_pages.#{stage_key}.further_learning.items",
      default: []
    )
    resource_overrides = t(
      "our_resources.stage_pages.#{stage_key}.further_learning.overrides",
      default: {}
    ).with_indifferent_access

    resource_keys.map do |key|
      resource_profiles.fetch(key).merge(resource_overrides[key] || {})
    end
  end

  private

  def youtube_embed_url(url)
    Renderers::Youtube.embed_url(url)
  end
end
