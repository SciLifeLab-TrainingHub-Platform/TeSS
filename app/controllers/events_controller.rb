require 'tzinfo'

# The controller for actions related to the Events model
class EventsController < ApplicationController
  before_action :feature_enabled?
  before_action :set_event, only: %i[show edit clone update destroy update_collections add_term reject_term
                                     redirect report update_report add_data reject_data]
  before_action :set_breadcrumbs
  before_action :disable_pagination, only: :index, if: ->(controller) { controller.request.format.ics? or controller.request.format.csv? or controller.request.format.rss? }
  before_action :set_event_dependencies, only: [:new, :clone, :edit, :create, :update]
  before_action :formatNodeIdsForRadio, only: [:create, :update]
  before_action :authorize_event_access, only: [:show, :edit, :update]
  after_action :event_change_status_and_notify_admin, only: [:update]


  include SearchableIndex
  include ActionView::Helpers::TextHelper
  include FieldLockEnforcement
  include TopicCuration

  # GET /events
  # GET /events.json
  def index
    preload_index_associations if request.format.html?
    @bioschemas = @events.flat_map(&:to_bioschemas)

    respond_to do |format|
      format.html
      format.json
      format.json_api { render({ json: @events }.merge(api_collection_properties)) }
      format.csv
      format.ics
      format.rss
    end
  end

  # GET /events/calendar
  # GET /events/calendar.js
  def calendar
    # set a higher limit so we ensure to have enough results to fill a month
    params[:per_page] ||= 200
    @start_date = Date.parse(params.fetch(:start_date, Date.today.to_s)).beginning_of_month

    set_params

    # override @facet_params to get only events relevant for the current month view
    @facet_params[:running_during] = "#{Date.today.beginning_of_day}/#{@start_date + 1.month}"
    fetch_resources
    events_set = @events

    @facet_params[:running_during] = "#{@start_date}/#{@start_date + 1.month}"
    fetch_resources
    events_set += @events

    @events = events_set.to_set.to_a

    # now customize the list by moving all events longer than 3 days into a separate array
    @long_events, _short_events = @events.partition { |e| e.end.nil? || e.start.nil? || e.start + TeSS::Config.site.fetch(:calendar_event_maxlength, 5).to_i.days < e.end }

    respond_to do |format|
      format.js
      format.html
    end
  end

  # GET /events/1
  # GET /events/1.json
  # GET /events/1.ics
  def show
    authorize @event
    @bioschemas = @event.to_bioschemas
    respond_to do |format|
      format.html
      format.json
      format.json_api { render json: @event }
      format.ics { send_data @event.to_ical, type: 'text/calendar', disposition: 'attachment', filename: "#{@event.slug}.ics" }
    end
  end

  def preview
    @event = User.get_default_user.events.new(event_params)

    respond_to do |format|
      if @event.valid?
        @bioschemas = @event.to_bioschemas
        format.html { render :show }
      else
        flash[:error] = 'This resource is invalid.'
        format.html { render 'bioschemas/test', status: :unprocessable_entity }
      end
    end
  end

  # GET /events/new
  def new
    authorize Event
    @event = Event.new(start: DateTime.now.change(hour: 9),
                       end: DateTime.now.change(hour: 17),
                       timezone: 'Stockholm')
    @selected_venue_ids = []
    @selected_cities_ids = []
    @selected_topics_ids = []
    @selected_content_providers_id = []
    @prefill_error = 'Please select a course first.' if params[:prefill].present? && params[:course_id].blank?
    @prefill_course = load_prefill_course
    apply_course_prefill if @prefill_course
  end

  # GET /events/1/clone
  def clone
    authorize @event
    @event = @event.duplicate
    render :new
  end

  # GET /events/1/edit
  def edit
    authorize @event
    @selected_venue_ids = @event.venues.pluck(:id)
    @selected_cities_ids = @event.cities.pluck(:id)
    @selected_topics_ids = @event.topics.pluck(:id)
    @selected_content_providers_id = @event.content_providers.pluck(:id)
  end

  # GET /events/1/report
  def report
    authorize @event, :edit_report?
  end

  # PATCH /events/1/report
  def update_report
    authorize @event, :edit_report?

    respond_to do |format|
      if @event.update(event_report_params)
        @event.create_activity(:report, owner: current_user) if @event.log_update_activity?

        format.html { redirect_to event_path(@event, anchor: 'report'), notice: 'Event report successfully updated.' }
        format.json { render :show, status: :ok, location: @event }
      else
        format.html { render :report }
        format.json { render json: @event.errors, status: :unprocessable_entity }
      end
    end
  end

  # POST /events/check_exists
  # POST /events/check_exists.json
  def check_exists
    @event = Event.check_exists_candidates(event_params)
                 .limit(50)
                 .find { |event| event_disclosable_for_check_exists?(event) }

    if @event
      respond_to do |format|
        format.html { redirect_to @event }
        format.json do
          render json: { id: @event.id, title: @event.title }, status: :ok, location: @event
        end
      end
    else
      respond_to do |format|
        format.html { head :ok }
        format.json { render json: {}, status: 200, content_type: 'application/json' }
      end
    end
  end

  # POST /events
  # POST /events.json
  def create
    authorize Event
    @event = Event.new(event_params)
    @event.user = current_user

    # Handle existing venue IDs
    if params[:event][:venue_ids].present?
      params[:event][:venue_ids] = params[:event][:venue_ids].reject(&:blank?)
    end

    # Handle existing cities IDs
    if params[:event][:city_ids].present?
      params[:event][:city_ids] = params[:event][:city_ids].reject(&:blank?)
    end

    # Handle existing content provider ids
    if params[:event][:content_provider_ids].present?
      params[:event][:content_provider_ids] = params[:event][:content_provider_ids].reject(&:blank?)
    end

    # Create new venues if provided
    if params[:event][:new_venues].present?
      @event.venue = params[:event][:new_venues]
    end

    respond_to do |format|
      if @event.save

        @event.create_activity :create, owner: current_user
        format.html { redirect_to @event, notice: 'Event was successfully created.' }
        format.json { render :show, status: :created, location: @event }
      else
        format.html { render :new }
        format.json { render json: @event.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /events/1
  # PATCH/PUT /events/1.json
  def update
    authorize @event

    # Handle existing venue IDs
    if params[:event][:venue_ids].present?
      params[:event][:venue_ids] = params[:event][:venue_ids].reject(&:blank?)
    end

    # Handle existing cities IDs
    if params[:event][:city_ids].present?
      params[:event][:city_ids] = params[:event][:city_ids].reject(&:blank?)
    end

    # Handle existing content provider ids
    if params[:event][:content_provider_ids].present?
      params[:event][:content_provider_ids] = params[:event][:content_provider_ids].reject(&:blank?)
    end

    # Create new venues if provided
    if params[:event][:new_venues].present?
      venue_names = params[:event][:new_venues].split(Event::VENUE_NAME_SEPARATOR).map(&:strip).reject(&:empty?)
      new_venues = venue_names.map { |name| Venue.find_or_create_by(name: name) }
      params[:event][:venue_ids].concat(new_venues.pluck(:id))
    end

    respond_to do |format|
      if @event.update(event_params)
        @event.create_activity(:update, owner: current_user) if @event.log_update_activity?
        format.html { redirect_to @event, notice: 'Event was successfully updated.' }
        format.json { render :show, status: :ok, location: @event }
      else
        format.html { render :edit }
        format.json { render json: @event.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /events/1
  # DELETE /events/1.json
  def destroy
    authorize @event
    @event.create_activity :destroy, owner: current_user
    @event.venues.clear
    @event.cities.clear
    @event.destroy
    respond_to do |format|
      format.html { redirect_to events_url, notice: 'Event was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  # POST /events/1/update_collections
  # POST /events/1/update_collections.json
  def update_collections
    # Go through each selected collection
    # and update its resources to include this one.
    # Go through each other collection
    collections = params[:event][:collection_ids].select { |p| !p.blank? }
    collections = collections.collect { |collection| Collection.find_by_id(collection) }
    collections_to_remove = @event.collections - collections
    collections.each do |collection|
      collection.update_resources_by_id(nil, (collection.events + [@event.id]).uniq)
    end
    collections_to_remove.each do |collection|
      collection.update_resources_by_id(nil, (collection.events.collect { |x| x.id } - [@event.id]).uniq)
    end
    flash[:notice] = "Event has been included in #{pluralize(collections.count, 'collection')}"
    redirect_to @event
  end

  def redirect
    log_params = request.query_parameters.slice('widget')

    @event.widget_logs.create(
      widget_name: params[:widget],
      action: "#{controller_name}##{action_name}",
      data: @event.url,
      params: log_params
    )

    redirect_to @event.url, allow_other_host: true
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_event
    @event = Event.friendly.find(params[:id])
  end

  def event_disclosable_for_check_exists?(event)
    return false unless policy(event).show?

    if event.respond_to?(:from_shadowbanned?) && event.from_shadowbanned?
      return false unless current_user&.shadowbanned? || current_user&.is_admin?
    end

    return true if current_user&.has_role?('admin')
    return true if current_user && event.user_id == current_user.id && !event.declined?
    return true if event.approved?

    false
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def event_params
    params.require(:event).permit(:external_id, :title, :subtitle, :url, :last_scraped, :registration_form_url, :scraper_record,
                                  :description, :course_id,  { :topic_ids => [] }, { scientific_topic_names: [] }, { scientific_topic_uris: [] },
                                  { operation_names: [] }, { operation_uris: [] }, { event_types: [] },
                                  { keywords: [] }, { fields: [] }, :start, :end, :application_deadline, :duration, { sponsors: [] },
                                  :online, { :venue_ids => [] }, :new_venues, { :city_ids => [] }, :county, :country, :postcode, :latitude, :longitude,
                                  :timezone, { :content_provider_ids => [] }, { collection_ids: [] }, { node_ids: [] },
                                  { node_names: [] }, { target_audience: [] }, { eligibility: [] }, :visible,
                                  { host_institutions: [] }, :capacity, :contact, :recognition, :learning_objectives,
                                  :prerequisites, :tech_requirements, :cost_basis, :cost_value, :cost_currency, :language,
                                  external_resources_attributes: %i[id url title _destroy],
                                  external_resources: [:url, :title], material_ids: [],
                                  llm_interaction_attributes: %i[id scrape_or_process model prompt input output needs_processing _destroy],
                                  locked_fields: [])
  end

  def event_report_params
    params.require(:event).permit(:funding, :attendee_count, :applicant_count, :trainer_count, :feedback, :notes)
  end

  def disable_pagination
    params[:per_page] = 2 ** 10
  end

  def preload_index_associations
    return unless @events.present?

    ActiveRecord::Associations::Preloader.new(
      records: @events,
      associations: [
        :nodes,
        { content_providers: :node }
      ]
    ).call
  end

  def set_event_dependencies
    @show_prefill = params[:id].blank?
    @venues = Venue.all
    @topics = Topic.all
    @content_providers = ContentProvider.all
    @courses = policy_scope(Course).select(:id, :title, :slug).order(:title).limit(100) if @show_prefill
    @country_code = if @event
                      JSON.parse(File.read(File.join(Rails.root, 'config', 'data', 'countries.json'))).key(@event.country) || "SE"
                    else
                      "SE"
                    end
    @cities = City.where(country_code: @country_code).or(City.online).order(:name)
  end

  def formatNodeIdsForRadio
      params[:event][:node_ids] = Array(params[:event][:node_ids])
  end

  def load_prefill_course
    return nil if params[:event].present?
    return nil if params[:course_id].blank?

    course = Course.friendly.includes(:content_providers).find(params[:course_id])
    authorize course, :show?
    course
  rescue ActiveRecord::RecordNotFound, Pundit::NotAuthorizedError
    @prefill_error = 'Course not found.'
    nil
  end

  def apply_course_prefill
    result = CourseToEventPrefiller.prefill(@event, @prefill_course, current_user)
    @prefill_applied_fields = result.applied_fields
    @prefill_warnings = result.warnings
  end

  def authorize_event_access
    # If the user is an admin, allow full access
    return if current_user&.has_role?('admin')

    # If the user is the owner, allow access only if the event is not declined
    return if current_user && @event.user_id == current_user.id && !@event.declined?

    # If the event is approved, allow access to anyone (logged-in or not)
    return if @event.approved?

    # If none of these conditions are met, then event cant be shown
    raise ActiveRecord::RecordNotFound
  end

  ##
  # This function notifies the admin and changes the event status
  # when the owner (current_user) updates the event,
  # if the event status is "revisions_required".
  def event_change_status_and_notify_admin
    Notifications::EventNotifier.new(@event).reset_status_and_notify_admin(current_user)
  end
end
