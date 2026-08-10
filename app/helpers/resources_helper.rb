module ResourcesHelper
  def resource_lifecycle_stages(active_key: nil)
    [
      { key: :plan_design, path: plan_design_stage_path },
      { key: :develop, path: develop_stage_path },
      { key: :deliver, path: deliver_stage_path },
      { key: :evaluate_archive, path: evaluate_archive_stage_path }
    ].map do |stage|
      lifecycle_locale_key = "resources.landing.lifecycle.stages.#{stage[:key]}"
      stage_page_locale_key = "resources.stage_pages.#{stage[:key]}"

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
    stage_page_sections(stage_key).values.map do |section|
      {
        anchor: section[:anchor],
        title: section[:nav_title] || section[:title]
      }
    end
  end

  def stage_page_sections(stage_key)
    t("resources.stage_pages.#{stage_key}.sections", default: {})
  end

  def stage_page_contributors(stage_key)
    contributor_profiles = t('resources.stage_pages.contributor_profiles', default: {})
    contributor_keys = t(
      "resources.stage_pages.#{stage_key}.contributors",
      default: []
    )

    # I18n symbolizes YAML mapping keys, while identifiers in YAML lists remain strings.
    contributor_keys.map do |contributor_key|
      contributor_profiles.fetch(contributor_key.to_sym)
    end
  end

  def stage_page_further_learning(stage_key)
    resource_profiles = t('resources.stage_pages.learning_resource_profiles', default: {})
    resource_keys = t(
      "resources.stage_pages.#{stage_key}.further_learning.items",
      default: []
    )
    resource_overrides = t("resources.stage_pages.#{stage_key}.further_learning.overrides", default: {})

    resource_keys.map do |resource_identifier|
      resource_key = resource_identifier.to_sym
      resource_profiles.fetch(resource_key).merge(resource_overrides[resource_key] || {})
    end
  end

  def resources_link_options(url)
    return {} unless url.to_s.start_with?('http://', 'https://')

    { target: '_blank', rel: 'noopener noreferrer' }
  end

  def youtube_embed_url(url)
    Renderers::Youtube.embed_url(url)
  end
end
