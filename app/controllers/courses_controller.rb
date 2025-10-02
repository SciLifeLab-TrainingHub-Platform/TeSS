# Controller for actions related to the Course model
class CoursesController < ApplicationController
  before_action -> { feature_enabled?('courses') }
  before_action :set_course, only: %i[show edit update destroy]

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
  end

  # GET /courses/1/edit
  def edit
    authorize @course
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
    permitted = [:title, :description, :language, :url, :licensing,
                 :structure_and_duration, :learning_outcomes, :prerequisites_knowledge,
                 :prerequisites_technical, { keywords: [] }, { authors: [] }, { contributors: [] },
                 :target_audience, :node_id, :user_id]

    permitted.delete(:user_id) unless current_user&.is_admin?

    params.require(:course).permit(permitted)
  end
end
