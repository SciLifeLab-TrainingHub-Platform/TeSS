# Controller for actions related to the Course model
class CoursesController < ApplicationController
  before_action -> { feature_enabled?('courses') }
  before_action :set_course, only: %i[show edit update destroy]
  before_action :set_course_dependencies, only: [:new, :edit, :create, :update]
  before_action :set_breadcrumbs

  after_action :course_change_status_and_notify_admin, only: [:update]
  before_action :authorize_course_access, only: [:show, :edit, :update]

  include SearchableIndex

  # GET /courses
  def index
    preload_index_associations if request.format.symbol == :html || request.format.symbol == :json

    respond_to do |format|
      format.html
      format.json
      format.json_api { render({ json: @courses }.merge(api_collection_properties)) }
    end
  end

  # GET /courses/1
  def show
    authorize @course
    respond_to do |format|
      format.html
      format.json
      format.json_api { render json: @course }
    end
  end

  # GET /courses/new
  def new
    authorize Course
    @course = Course.new
    @selected_content_providers_id = []
    @selected_events_id = []
  end

  # GET /courses/1/edit
  def edit
    authorize @course
    @selected_content_providers_id = @course.content_providers.pluck(:id)
    @selected_events_id = @course.events.pluck(:id)
  end

  # POST /courses
  def create
    authorize Course
    normalize_authors_and_contributors
    normalize_node_ids
    @course = Course.new(course_params)
    @course.user = current_user if @course.respond_to?(:user=)

    respond_to do |format|
      if @course.save
        @course.create_activity :create, owner: current_user if @course.respond_to?(:create_activity)
        format.html { redirect_to @course, notice: 'Course was successfully created.' }
        format.json { render :show, status: :created, location: @course }
      else
        format.html { render :new }
        format.json { render json: @course.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /courses/1
  def update
    authorize @course
    normalize_authors_and_contributors
    normalize_node_ids

    respond_to do |format|
      if @course.update(course_params)
        @course.create_activity(:update, owner: current_user) if @course.respond_to?(:create_activity)
        format.html { redirect_to @course, notice: 'Course was successfully updated.' }
        format.json { render :show, status: :ok, location: @course }
      else
        format.html { render :edit }
        format.json { render json: @course.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /courses/1
  def destroy
    authorize @course
    @course.create_activity :destroy, owner: current_user if @course.respond_to?(:create_activity)
    @course.destroy
    respond_to do |format|
      format.html { redirect_to courses_url, notice: 'Course was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  def check_exists
    @course = Course.check_exists_candidates(course_check_exists_params)
                    .limit(50)
                    .find { |course| course_disclosable_for_check_exists?(course) }

    if @course
      respond_to do |format|
        format.html { redirect_to @course }
        format.json do
          render json: { id: @course.id, title: @course.title }, status: :ok, location: @course
        end
      end
    else
      respond_to do |format|
        format.html { head :ok }
        format.json { render json: {}, status: 200, content_type: 'application/json' }
      end
    end
  end

  private

  def course_disclosable_for_check_exists?(course)
    return false unless policy(course).show?

    if course.respond_to?(:from_shadowbanned?) && course.from_shadowbanned?
      return current_user&.shadowbanned? || current_user&.is_admin?
    end

    true
  end

  # Use callbacks to share common setup or constraints
  def set_course
    @course = Course.includes(
      :nodes,
      :user,
      { content_providers: :node },
      { events: [:content_providers] }
    ).friendly.find(params[:id])
  end

  # Only allow trusted parameters
  def course_params
    permitted = [
      :title, :description, :language, :url, :licence,
      :structure_and_duration, :learning_outcomes, :prerequisites_knowledge,
      :prerequisites_technical,
      { keywords: [] },
      { target_audience: [] },
      { authors: [:name, :affiliation, :orcid, :email] },
      { contributors: [:name, :affiliation, :orcid, :email] },
      { event_ids: [] },
      { content_provider_ids: [] },
      { node_ids: [] }
    ]

    permitted.delete(:user_id) unless current_user&.is_admin?

    params.require(:course).permit(permitted)
  end

  def course_check_exists_params
    params.require(:course).permit(:title, :url, :content_provider_id, content_provider_ids: [])
  end

  def set_course_dependencies
    @content_providers = ContentProvider.all
    @events = Event.all
  end

  def normalize_authors_and_contributors
    return unless params[:course].is_a?(ActionController::Parameters) || params[:course].is_a?(Hash)

    [:authors, :contributors].each do |key|
      raw_value = params[:course][key]
      next unless raw_value.is_a?(String)

      if raw_value.blank?
        params[:course][key] = []
        next
      end

      params[:course][key] = JSON.parse(raw_value)
    rescue JSON::ParserError => e
      Rails.logger.warn("CoursesController#normalize_authors_and_contributors: invalid JSON for #{key}: #{e.message}")
      params[:course].delete(key)
    end
  end

  def normalize_node_ids
    if params[:course][:node_ids].is_a?(String)
      params[:course][:node_ids] = [params[:course][:node_ids]]
    end
  end

  def preload_index_associations
    return unless @courses.present?

    ActiveRecord::Associations::Preloader.new(
      records: @courses,
      associations: [
        :nodes,
        { content_providers: :node },
        :events
      ]
    ).call
  end

  ##
  # This function notifies the admin and changes the event status
  # when the owner (current_user) updates the event,
  # if the event status is "revisions_required".
  def course_change_status_and_notify_admin
    Notifications::CourseNotifier.new(@event).reset_status_and_notify_admin(current_user)
  end

  def authorize_course_access
    # If the user is an admin, allow full access
    return if current_user&.has_role?('admin')

    # If the user is the owner, allow access only if the course is not declined
    return if current_user && @course.user_id == current_user.id && !@course.declined?

    # If the course is approved, allow access to anyone (logged-in or not)
    return if @course.approved?

    # If none of these conditions are met, then course can't be shown
    raise ActiveRecord::RecordNotFound
  end
end
