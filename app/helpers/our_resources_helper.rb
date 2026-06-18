module OurResourcesHelper
  def resource_lifecycle_stages(active_key: nil)
    [
      { key: :design_develop, path: design_develop_path },
      { key: :plan, path: guides_path },
      { key: :deliver, path: community_path },
      { key: :evaluate_archive, path: fair_path }
    ].map do |stage|
      locale_key = "our_resources.landing.lifecycle.stages.#{stage[:key]}"

      {
        timeframe: t("#{locale_key}.timeframe"),
        title: t("#{locale_key}.title"),
        description: t("#{locale_key}.description"),
        path: stage[:path],
        active: stage[:key] == active_key
      }
    end
  end

  def design_develop_resources
    guide_resources_for(:resource_collections)
  end

  def design_develop_sections
    t('our_resources.stage_pages.design_develop.sections').with_indifferent_access.values
  end

  def design_develop_contributors
    t('our_resources.stage_pages.design_develop.contributors').with_indifferent_access.values
  end

  private

  def guide_resources_for(category_key)
    category = t("guides.#{category_key}", default: {}).with_indifferent_access

    category.fetch(:elements, {}).map do |_key, resource|
      {
        title: resource[:name],
        image: resource[:image],
        url: resource[:url]
      }
    end
  end
end
