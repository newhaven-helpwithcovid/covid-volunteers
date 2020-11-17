class ProjectsController < ApplicationController
  before_action :authenticate_user!, only: [ :new, :create, :edit, :update, :destroy, :toggle_volunteer, :volunteered, :own, :volunteers ]
  before_action :set_project, only: [ :show, :edit, :update, :destroy, :toggle_volunteer, :volunteers ]
  before_action :ensure_owner_or_admin, only: [ :edit, :update, :destroy, :volunteers ]
  before_action :set_filters_open, only: :index
  before_action :set_projects_query, only: :index

  $removeMode = false;

  def index
    params[:page] ||= 1
    @show_filters = true
    @show_search_bar = true
    @show_sorting_options = true

    respond_to do |format|
      format.html do
        @projects_header = "#{CITY_NAME} Residents vs. COVID-19"
        @projects_subheader = "This is a #{CITY_NAME}-wide partnership platform, where #{CITY_NAME} residents can volunteer (in-person or remotely) and local non-profits and government can post volunteer needs. Let us unite and fight the pandemic together!"
        @page_title = 'All Projects'

        @projects = Kaminari.paginate_array(@projects.select {|project| project.is_visible_to_user?(current_user)})
        @projects = @projects.page(params[:page]).per(25)

        @index_from = (@projects.prev_page || 0) * @projects.current_per_page + 1
        @index_to = [@index_from + @projects.current_per_page - 1, @projects.total_count].min
        @total_count = @projects.total_count
      end
      format.json do
        render json: @projects
      end
    end
  end

  def volunteered
    params[:page] ||= 1

    @projects = current_user.volunteered_projects.page(params[:page]).per(25)
    @index_from = (@projects.prev_page || 0) * @projects.current_per_page + 1
    @index_to = [@index_from + @projects.current_per_page - 1, @projects.total_count].min

    @projects_header = 'Opportunities You\'ve Volunteered For'
    @projects_subheader = 'These are the projects where you volunteered.'
    @page_title = 'Volunteered Projects'
    render action: 'index'
  end

  def own
    params[:page] ||= 1

    @projects = current_user.projects.page(params[:page]).per(25)

    @index_from = (@projects.prev_page || 0) * @projects.current_per_page + 1
    @index_to = [@index_from + @projects.current_per_page - 1, @projects.total_count].min

    @projects_header = 'Opportunities You\'ve Posted'
    @projects_subheader = 'These are the volunteer positions you created.'
    @page_title = 'Own Projects'
    render action: 'index'
  end

  def show
    respond_to do |format|
      format.html
      format.json { render json: @project }
    end
  end

  def volunteers
    respond_to do |format|
      format.csv { send_data @project.volunteered_users.to_csv, filename: "volunteers-#{Date.today}.csv" }
    end
  end

  def new
    @project = Project.new
  end

  def create
    @project = Project.new(project_params)

    @project.user = current_user

    if @project.save
      ProjectMailer.with(project: @project).new_project.deliver_now
      # TODO: temporary debugging
      if @project.user.email == 'wolf.honore@yale.edu'
        ProjectMailer.with(project: @project).reminder.deliver_later(wait: 30.seconds)
      end
    end

    respond_to do |format|
      if @project.save
        format.html { redirect_to @project, notice: 'Project was successfully created.' }
        format.json { render :show, status: :created, location: @project }
      else
        format.html { render :new }
        format.json { render json: @project.errors, status: :unprocessable_entity }
      end
    end
  end

  def edit
    if params[:act] == "remove"
      $removeMode = true;
    else
      $removeMode = false;
    end
  end

  def update
    respond_to do |format|

      if $removeMode == true
        if @project.update(project_params)
          @project.update_attribute(:visible, false);
          format.html { redirect_to projects_url, notice: 'Project was successfully deleted.' }
          format.json { head :no_content }
        else
          format.html { render :edit }
          format.json { render json: @project.errors, status: :unprocessable_entity }
        end
      else
        if @project.update(project_params)
          format.html { redirect_to @project, notice: 'Project was successfully updated.' }
          format.json { render :show, status: :ok, location: @project }
        else
          format.html { render :edit }
          format.json { render json: @project.errors, status: :unprocessable_entity }
        end
      end
    end
  end

  def destroy
    @project.destroy
    respond_to do |format|
      format.html { redirect_to projects_url, notice: 'Project was successfully deleted.' }
      format.json { head :no_content }
    end
  end

  def toggle_volunteer
    if @project.volunteered_users.include?(current_user)
      @project.volunteers.where(user: current_user).destroy_all
      flash[:notice] = "We've removed you from the list of volunteered people."
    else
      @project.volunteered_users << current_user

      ProjectMailer.with(project: @project, user: current_user).new_volunteer.deliver_now

      flash[:notice] = 'Thanks for volunteering! The hiring manager will be alerted.'
    end

    redirect_to project_path(@project)
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_project
      @project = Project.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def project_params
      params.fetch(:project, {}).permit(:name, :organization, :organization_mission, :organization_registered, :level_of_urgency, :level_of_exposure, :description, :participants, :looking_for, :contact, :location, :start_date, :end_date, :end_date_recurring, :compensation, :background_screening_required, :progress, :docs_and_demo, :number_of_volunteers, :was_helpful, :exit_comments, :visible, :skill_list => [], :project_type_list => [], :vol_list => [])
    end

    def ensure_owner_or_admin
      if (current_user != @project.user || !@project.visible) && !current_user.is_admin?
        flash[:error] = "Apologies, you don't have access to this."
        redirect_to projects_path
      end
    end

    def set_projects_query
      applied_skills = (params[:skills] or '').split(',')
      applied_project_types = (params[:project_types] or '').split(',')
      applied_project_locations = (params[:location] or '').split(',')

      @projects = Project
      @projects = @projects.tagged_with(applied_skills) if applied_skills.length > 0
      @projects = @projects.tagged_with(applied_project_types) if applied_project_types.length > 0
      @projects = @projects.where("location LIKE ?", "%" + applied_project_locations[0] + "%") if applied_project_locations.length == 1
      @projects = @projects.where(location: applied_project_locations) if applied_project_locations.length > 1

      if params[:query].present?
        @projects = @projects.search(params[:query]).left_joins(:volunteers).reorder(nil).group(:id)
      else
        @projects = @projects.left_joins(:volunteers).group(:id)
      end

      if params[:sort_by]
        @projects = @projects.order(get_order_param)
      else
        @projects = @projects.order('highlight DESC, COUNT(volunteers.id) ASC, created_at DESC')
      end

      @projects.includes(:project_types, :skills, :vols)
    end

    def get_order_param
      return 'created_at desc' if params[:sort_by] == 'latest'
      return 'volunteers.count asc' if params[:sort_by] == 'volunteers_needed'
    end
end
