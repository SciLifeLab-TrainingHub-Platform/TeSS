# Controller for actions related to the Course model
class CoursesController < ApplicationController
  before_action -> { feature_enabled?('courses') }
  before_action :set_course, only: %i[show edit update destroy]
  before_action :set_course_dependencies, only: [:new, :edit, :create, :update]
  before_action :normalize_authors_and_contributors, only: [:create, :update]

  include SearchableIndex

  # GET /courses
  def index
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

  private

  # Use callbacks to share common setup or constraints
  def set_course
    @course = Course.friendly.find(params[:id])
  end

  # Only allow trusted parameters
  def course_params
    permitted = [:title, :description, :language, :url, :licence,
                 :structure_and_duration, :learning_outcomes, :prerequisites_knowledge,
                 :prerequisites_technical, { keywords: [] }, { authors: [] }, { contributors: [] },
                 :target_audience, :node_id, :user_id, { :content_provider_ids => [] }, { :event_ids => [] }]

    permitted.delete(:user_id) unless current_user&.is_admin?

    params.require(:course).permit(permitted)
  end

  def set_course_dependencies
    @content_providers = ContentProvider.all
    @events = Event.all
  end

  def normalize_authors_and_contributors
    if params[:author_name]
      authors = params[:author_name].each_index.map do |i|
        {
          name: params[:author_name][i],
          affiliation: params[:author_affiliation][i],
          orcid: params[:author_orcid][i],
          email: params[:author_email][i]
        }
      end
      params[:course][:authors] = authors
    end

    if params[:contributor_name]
      contributors = params[:contributor_name].each_index.map do |i|
        {
          name: params[:contributor_name][i],
          affiliation: params[:contributor_affiliation][i],
          orcid: params[:contributor_orcid][i]
        }
      end
      params[:course][:contributors] = contributors
    end
  end
end
