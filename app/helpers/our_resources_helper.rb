module OurResourcesHelper
  def resource_lifecycle_stages
    [
      { key: :design_develop, path: guides_path },
      { key: :plan, path: guides_path },
      { key: :deliver, path: community_path },
      { key: :evaluate_archive, path: fair_path }
    ].map do |stage|
      locale_key = "our_resources.landing.lifecycle.stages.#{stage[:key]}"

      {
        timeframe: t("#{locale_key}.timeframe"),
        title: t("#{locale_key}.title"),
        description: t("#{locale_key}.description"),
        path: stage[:path]
      }
    end
  end
end
