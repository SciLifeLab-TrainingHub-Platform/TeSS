# Controller for actions related to the Course model
class CoursesController < ApplicationController
  before_action -> { feature_enabled?('courses') }
  before_action :set_course, only: %i[show edit update destroy]
  before_action :set_course_dependencies, only: [:new, :edit, :create, :update]
  before_action :set_breadcrumbs

  include SearchableIndex

  # GET /courses
  def index
    preload_index_associations if request.format.html?

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
    @course = Course.check_exists(course_params)

    if @course
      respond_to do |format|
        format.html { redirect_to @course }
        format.json { render :show, location: @course }
      end
    else
      respond_to do |format|
        format.html { render nothing: true, status: 200, content_type: 'text/html' }
        format.json { render json: {}, status: 200, content_type: 'application/json' }
      end
    end
  end


  private

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

  def set_course_dependencies
    @content_providers = ContentProvider.all
    @events = Event.all
  end

  def normalize_authors_and_contributors
    [:authors, :contributors].each do |key|
      if params[:course][key].is_a?(String)
        params[:course][key] = JSON.parse(params[:course][key]) rescue []
      end
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
        :content_providers,
        { events: :content_providers }
      ]
    ).call
  end
end
