module OurResourcesHelper
  def resource_lifecycle_stages(active_key: nil)
    [
      { key: :plan_design, path: plan_design_stage_path },
      { key: :develop, path: develop_stage_path },
      { key: :deliver, path: deliver_stage_path },
      { key: :evaluate_archive, path: evaluate_archive_stage_path }
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

  def plan_design_section_links
    stage_page_section_links(
      :design_develop,
      section_keys: %i[target_audience learning_outcomes engagement]
    )
  end

  def develop_section_links
    stage_page_section_links(
      :develop,
      section_keys: %i[announcement training_page computational_tools fair_materials]
    )
  end

  def deliver_section_links
    stage_page_section_links(
      :deliver,
      section_keys: %i[facilitation tools feedback]
    )
  end

  def evaluate_archive_section_links
    stage_page_section_links(
      :evaluate_archive,
      section_keys: %i[prepare_materials archive oer_communities reflections]
    )
  end

  def plan_design_further_learning
    stage_page_further_learning(:design_develop)
  end

  def design_develop_contributors
    stage_page_contributors(:design_develop)
  end

  def develop_further_learning
    stage_page_further_learning(:develop)
  end

  def develop_contributors
    stage_page_contributors(:develop)
  end

  def deliver_further_learning
    stage_page_further_learning(:deliver)
  end

  def evaluate_archive_further_learning
    stage_page_further_learning(:evaluate_archive)
  end

  def deliver_contributors
    stage_page_contributors(:deliver)
  end

  private

  def stage_page_section_links(stage_key, section_keys:)
    section_keys.map do |section_key|
      section = t("our_resources.stage_pages.#{stage_key}.sections.#{section_key}").with_indifferent_access

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
    t("our_resources.stage_pages.#{stage_key}.further_learning.items", default: {})
      .with_indifferent_access
      .values
  end

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

  def youtube_embed_url(url)
    return if url.blank?

    parsed_url = URI.parse(url)
    host = parsed_url.host.to_s.downcase

    return unless %w[http https].include?(parsed_url.scheme)
    return unless %w[youtube.com youtu.be m.youtube.com www.youtube.com].include?(host)

    video_id = if host == 'youtu.be'
                 parsed_url.path.delete_prefix('/').split('/').first
               else
                 url.match(/[\?&]v[i]?=([-_a-zA-Z0-9]+)/)&.captures&.first ||
                   url.match(%r{/v/([-_a-zA-Z0-9]+)})&.captures&.first ||
                   url.match(%r{/embed/([-_a-zA-Z0-9]+)})&.captures&.first
               end

    "https://www.youtube.com/embed/#{video_id}" if video_id.present?
  rescue URI::InvalidURIError
    nil
  end
end
