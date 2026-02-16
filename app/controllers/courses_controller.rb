# Controller for actions related to the Course model
class CoursesController < ApplicationController
  before_action -> { feature_enabled?('courses') }
  before_action :set_course, only: %i[show edit update destroy]
  before_action :set_course_dependencies, only: [:new, :edit, :create, :update]
  before_action :set_breadcrumbs

  before_action only: [:show, :edit, :update] do
    authorize_resource_access(@course)
  end

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
    @selected_events_id = (@course.events.pluck(:id) + @course.course_pending_events.pluck(:event_id)).uniq
  end

  # POST /courses
  def create
    authorize Course
    normalize_authors_and_contributors
    normalize_node_ids
    requested_event_ids = requested_event_ids_from_params
    direct_event_linking = current_user&.admin_or_trusted?
    @course = Course.new(course_params.except(:event_ids))
    @course.user = current_user if @course.respond_to?(:user=)

    respond_to do |format|
      if direct_event_linking
        begin
          ActiveRecord::Base.transaction do
            @course.save!
            apply_direct_event_selection!(requested_event_ids)
          end
        rescue ActiveRecord::RecordInvalid => e
          rolled_back_errors = e.record.is_a?(Course) ? e.record.errors : nil

          # If the transaction rolled back after a successful save!, @course can still appear persisted in-memory.
          # Always rebuild for render to ensure the form posts to create (not update) and the object reflects the DB.
          @course = Course.new(course_params.except(:event_ids))
          @course.user = current_user if @course.respond_to?(:user=)

          @course.errors.merge!(rolled_back_errors) if rolled_back_errors.present?
          @course.errors.add(:events, 'One or more selected events are invalid, not permitted, or unavailable.') unless rolled_back_errors.present?
          set_selected_ids_for_form
          format.html { render :new }
          format.json { render json: @course.errors, status: :unprocessable_entity }
          next
        rescue ActiveRecord::RecordNotUnique
          @course = Course.new(course_params.except(:event_ids))
          @course.user = current_user if @course.respond_to?(:user=)
          @course.errors.add(:events, 'One or more selected events are invalid, not permitted, or unavailable.')
          set_selected_ids_for_form
          format.html { render :new }
          format.json { render json: @course.errors, status: :unprocessable_entity }
          next
        end

        @course.create_activity :create, owner: current_user if @course.respond_to?(:create_activity)
        format.html { redirect_to @course, notice: 'Course was successfully created.' }
        format.json { render :show, status: :created, location: @course }
        next
      end

      unless validate_unapproved_event_selection(
        requested_event_ids,
        existing_linked_ids: [],
        existing_pending_ids: []
      )
        set_selected_ids_for_form
        format.html { render :new }
        format.json { render json: @course.errors, status: :unprocessable_entity }
        next
      end

      begin
        ActiveRecord::Base.transaction do
          @course.save!
          apply_unapproved_event_selection!(requested_event_ids)
        end
      rescue ActiveRecord::RecordInvalid => e
        if e.record.is_a?(CoursePendingEvent)
          @course = Course.new(course_params.except(:event_ids))
          @course.user = current_user if @course.respond_to?(:user=)
          @course.errors.add(:events, 'One or more selected events are invalid, not permitted, or unavailable.')
        end
        set_selected_ids_for_form
        format.html { render :new }
        format.json { render json: @course.errors, status: :unprocessable_entity }
        next
      rescue ActiveRecord::RecordNotUnique
        @course = Course.new(course_params.except(:event_ids))
        @course.user = current_user if @course.respond_to?(:user=)
        @course.errors.add(:events, 'One or more selected events are invalid, not permitted, or unavailable.')
        set_selected_ids_for_form
        format.html { render :new }
        format.json { render json: @course.errors, status: :unprocessable_entity }
        next
      end

      @course.create_activity :create, owner: current_user if @course.respond_to?(:create_activity)
      format.html { redirect_to @course, notice: 'Course was successfully created.' }
      format.json { render :show, status: :created, location: @course }
    end
  end

  # PATCH/PUT /courses/1
  def update
    authorize @course
    normalize_authors_and_contributors
    normalize_node_ids
    requested_event_ids = event_ids_param_present? ? requested_event_ids_from_params : nil
    update_params = course_params.except(:event_ids)

    respond_to do |format|
      begin
        ActiveRecord::Base.transaction do
          @course.lock!

          if @course.approved?
            @course.update!(update_params)
            apply_direct_event_selection!(requested_event_ids) if requested_event_ids

            # Enforce invariant: approved courses should not retain pending claims.
            @course.course_pending_events.delete_all
          else
            if requested_event_ids
              existing_linked_ids = @course.event_ids
              existing_pending_ids = @course.course_pending_events.pluck(:event_id)

              unless validate_unapproved_event_selection(
                requested_event_ids,
                existing_linked_ids: existing_linked_ids,
                existing_pending_ids: existing_pending_ids
              )
                raise ActiveRecord::RecordInvalid.new(@course)
              end
            end

            @course.update!(update_params)
            apply_unapproved_event_selection!(requested_event_ids) if requested_event_ids
          end
        end
      rescue ActiveRecord::RecordInvalid => e
        @course.errors.add(:events, 'One or more selected events are invalid, not permitted, or unavailable.') if requested_event_ids && !e.record.is_a?(Course)
        set_selected_ids_for_form
        format.html { render :edit }
        format.json { render json: @course.errors, status: :unprocessable_entity }
        next
      rescue ActiveRecord::RecordNotUnique
        @course.errors.add(:events, 'One or more selected events are invalid, not permitted, or unavailable.') if requested_event_ids
        set_selected_ids_for_form
        format.html { render :edit }
        format.json { render json: @course.errors, status: :unprocessable_entity }
        next
      end

      course_change_status_and_notify_admin
      @course.create_activity(:update, owner: current_user) if @course.respond_to?(:create_activity)
      format.html { redirect_to @course, notice: 'Course was successfully updated.' }
      format.json { render :show, status: :ok, location: @course }
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

  def set_selected_ids_for_form
    raw_params = params[:course]

    content_providers_key_present =
      raw_params.respond_to?(:key?) &&
        (raw_params.key?(:content_provider_ids) || raw_params.key?('content_provider_ids'))

    events_key_present =
      raw_params.respond_to?(:key?) &&
        (raw_params.key?(:event_ids) || raw_params.key?('event_ids'))

    @selected_content_providers_id =
      if content_providers_key_present
        Array(raw_params[:content_provider_ids]).reject(&:blank?).map(&:to_i)
      else
        @course&.content_provider_ids || []
      end

    @selected_events_id =
      if events_key_present
        Array(raw_params[:event_ids]).reject(&:blank?).map(&:to_i)
      else
        (@course&.event_ids || []) + (@course&.course_pending_events&.pluck(:event_id) || [])
      end
  end

  def course_check_exists_params
    params.require(:course).permit(:title, :url, :content_provider_id, content_provider_ids: [])
  end

  def set_course_dependencies
    @content_providers = ContentProvider.all
    approved_events = Event.where(event_status: Event.event_statuses[:approved])
    @events = if defined?(@course) && @course&.persisted?
                selected_event_ids = @course.event_ids + @course.course_pending_events.pluck(:event_id)
                approved_events.or(Event.where(id: selected_event_ids)).distinct.order(:title)
              else
                approved_events.order(:title)
              end
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
    return unless params[:course].is_a?(ActionController::Parameters) || params[:course].is_a?(Hash)

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

  # Notifies the admin and updates the course status
  # when the owner edits a course in "revisions_required" state.
  def course_change_status_and_notify_admin
    Notifications::CourseNotifier.new(@course).reset_status_and_notify_admin(current_user)
  end

  def event_ids_param_present?
    raw_params = params[:course]
    raw_params.respond_to?(:key?) &&
      (raw_params.key?(:event_ids) || raw_params.key?('event_ids'))
  end

  def requested_event_ids_from_params
    CourseEventLinkingEligibility.normalize_event_ids(params.dig(:course, :event_ids))
  end

  def validate_unapproved_event_selection(desired_event_ids, existing_linked_ids:, existing_pending_ids:)
    to_add = desired_event_ids - existing_linked_ids - existing_pending_ids
    to_unlink = existing_linked_ids - desired_event_ids

    unauthorized_additions =
      to_add - CourseEventLinkingEligibility.actor_manageable_event_ids(
        actor: current_user,
        request: request,
        event_ids: to_add
      )

    unauthorized_unlinks =
      to_unlink - CourseEventLinkingEligibility.actor_manageable_event_ids(
        actor: current_user,
        request: request,
        event_ids: to_unlink
      )

    invalid = false
    invalid ||= unauthorized_additions.any?
    invalid ||= unauthorized_unlinks.any?
    invalid ||= Event.where(id: to_add).where.not(event_status: Event.event_statuses[:approved]).exists?
    invalid ||= Event.where(id: to_add).where.not(course_id: nil).exists?
    invalid ||= CourseEventLinkingEligibility.pending_claim_conflict_event_ids(
      event_ids: to_add,
      course_id: @course&.id
    ).any?

    if invalid
      @course.errors.add(:events, 'One or more selected events are invalid, not permitted, or unavailable.')
      return false
    end

    true
  end

  def apply_unapproved_event_selection!(desired_event_ids)
    desired_event_ids ||= []

    existing_linked_ids = @course.event_ids
    existing_pending_ids = @course.course_pending_events.pluck(:event_id)

    to_add = desired_event_ids - existing_linked_ids - existing_pending_ids
    to_unlink = existing_linked_ids - desired_event_ids
    to_remove_pending = existing_pending_ids - desired_event_ids

    Event.where(id: to_unlink, course_id: @course.id).find_each do |event|
      event.update!(course_id: nil)
    end

    @course.course_pending_events.where(event_id: to_remove_pending).delete_all

    to_add.each do |event_id|
      @course.course_pending_events.create!(event_id: event_id)
    end
  end

  def apply_direct_event_selection!(desired_event_ids)
    desired_event_ids ||= []

    locked_events =
      Event.where(course_id: @course.id)
           .or(Event.where(id: desired_event_ids))
           .order(:id)
           .lock('FOR UPDATE')
           .to_a

    existing_linked_ids = locked_events.select { |e| e.course_id == @course.id }.map(&:id)

    unless validate_unapproved_event_selection(
      desired_event_ids,
      existing_linked_ids: existing_linked_ids,
      existing_pending_ids: []
    )
      raise ActiveRecord::RecordInvalid.new(@course)
    end

    to_add = desired_event_ids - existing_linked_ids
    to_unlink = existing_linked_ids - desired_event_ids

    Event.where(id: to_unlink, course_id: @course.id).find_each do |event|
      event.update!(course_id: nil)
    end

    Event.where(id: to_add, course_id: nil).find_each do |event|
      event.update!(course_id: @course.id)
    end

    @course.course_pending_events.delete_all
  end
end
