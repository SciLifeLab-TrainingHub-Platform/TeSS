# The controller for actions related to home page
class StaticController < ApplicationController
  skip_before_action :authenticate_user!, :authenticate_user_from_token!

  def privacy; end

  def home
    @hide_search_box = true
    @resources = []
    if TeSS::Config.solr_enabled
      enabled = []
      enabled.append(Event) if TeSS::Config.feature['events']
      enabled.append(Material) if TeSS::Config.feature['materials']
      enabled.append(Collection) if TeSS::Config.feature['collections']
      enabled.each do |resource|
        @resources += resource.search_and_filter(nil, '', { 'max_age' => '1 month' },
                                                 sort_by: 'new', per_page: 5).results
      end
    end

    @resources = @resources.sort_by(&:created_at).reverse

    @events = set_upcoming_events
    @materials = set_latest_materials
    @catalogue_count_strings = set_catalogue_count_strings
  end

  def showcase
    @container_class = 'showcase-container container-fluid'
  end

  def set_upcoming_events
    n_events = TeSS::Config.site.dig('home_page', 'upcoming_events')
    return [] unless n_events

    Event.search_and_filter(
      nil,
      '',
      { 'start' => "#{Date.tomorrow.beginning_of_day}/" },
      sort_by: 'early',
      per_page: n_events
    ).results
  end

  def set_featured_trainer
    return nil unless TeSS::Config.site.dig('home_page', 'featured_trainer')

    srand(Date.today.beginning_of_day.to_i)
    Trainer.order(:id).sample(1)
  end

  def set_upcoming_events
    n_events = TeSS::Config.site.dig('home_page', 'upcoming_events')
    return [] unless n_events

    Event.search_and_filter(
      nil,
      '',
      { 'start' => "#{Date.tomorrow.beginning_of_day}/" },
      sort_by: 'early',
      per_page: n_events
    ).results
  end

  def set_latest_materials
    n_materials = TeSS::Config.site.dig('home_page', 'latest_materials')
    return [] unless n_materials

    Material.search_and_filter(
      nil,
      '',
      { 'max_age' => '1 month' },
      sort_by: 'new',
      per_page: 10 * n_materials
    )&.results&.group_by(&:content_provider_id)&.map { |_p_id, p_materials| p_materials&.first }&.first(n_materials)
  end

  def set_upcoming_events
    n_events = TeSS::Config.site.dig('home_page', 'upcoming_events')
    return [] unless n_events

    Event.search_and_filter(
      nil,
      '',
      { 'start' => "#{Date.tomorrow.beginning_of_day}/" },
      sort_by: 'early',
      per_page: 5 * n_events
    ).results.group_by(&:content_provider_id).map { |_p_id, p_events| p_events.first }.first(n_events)
  end

  def set_catalogue_count_strings
    catalogue_count_strings = {}
    return catalogue_count_strings unless TeSS::Config.site.dig('home_page', 'catalogue_counts')

    total_events = Event.where.not(end: nil).where('events.end > ?', Time.zone.now).count
    last_month_events = Event.where('events.created_at > ?', 1.month.ago).count
    total_events = "#{total_events.round(-2).to_f / 1000}k" if total_events > 100
    last_month_events = "#{last_month_events.round(-2).to_f / 1000}k" if last_month_events > 100
    catalogue_count_strings['events'] = t('home.catalogue.events_count', total_events:, last_month_events:)
    # catalogue_count_strings['materials'] = t('home.catalogue.materials_count', total_materials: Material.all.count)
    catalogue_count_strings['materials'] = "#{Material.all.count} #{Material.model_name.human.pluralize.downcase}"
    catalogue_count_strings['workflows'] = "#{Workflow.all.count} #{Workflow.model_name.human.pluralize.downcase}"
    catalogue_count_strings['content_providers'] = "#{ContentProvider.all.count} #{ContentProvider.model_name.human.pluralize.downcase}"
    catalogue_count_strings['trainers'] = "#{Trainer.all.count} #{Trainer.model_name.human.pluralize.downcase}"
    catalogue_count_strings
  end
end
