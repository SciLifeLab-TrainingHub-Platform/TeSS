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
    %i[target_audience learning_outcomes engagement].map do |section_key|
      section = t("our_resources.stage_pages.design_develop.sections.#{section_key}").with_indifferent_access

      {
        anchor: section[:anchor],
        title: section[:title]
      }
    end
  end

  def plan_design_further_learning
    t('our_resources.stage_pages.design_develop.further_learning.items', default: {})
      .with_indifferent_access
      .values
  end

  def design_develop_contributors
    stage_page_contributors(:design_develop)
  end

  def develop_video
    t('our_resources.stage_pages.develop.video').with_indifferent_access
  end

  def develop_video_embed_url
    youtube_embed_url(develop_video[:url])
  end

  def develop_course_page
    t('our_resources.stage_pages.develop.course_page').with_indifferent_access
  end

  def develop_course_page_examples
    develop_course_page.fetch(:examples, {}).with_indifferent_access.values
  end

  def develop_resources
    stage_page_resources(:develop)
  end

  def develop_contributors
    stage_page_contributors(:develop)
  end

  def deliver_tools
    t('our_resources.stage_pages.deliver.tools.items', default: {}).with_indifferent_access.values
  end

  def deliver_sections
    stage_page_sections(:deliver)
  end

  def deliver_resources
    stage_page_resources(:deliver)
  end

  def deliver_contributors
    stage_page_contributors(:deliver)
  end

  private

  def stage_page_sections(stage_key)
    t("our_resources.stage_pages.#{stage_key}.sections", default: {}).with_indifferent_access.values
  end

  def stage_page_contributors(stage_key)
    t("our_resources.stage_pages.#{stage_key}.contributors", default: {}).with_indifferent_access.values
  end

  def stage_page_resources(stage_key)
    t("our_resources.stage_pages.#{stage_key}.resources", default: {}).with_indifferent_access.values.map do |resource|
      {
        title: resource[:title],
        image: resource[:image],
        url: resource[:url]
      }
    end
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
