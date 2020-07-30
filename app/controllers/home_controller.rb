# frozen_string_literal: true

class HomeController < ApplicationController
  before_action :hydrate_project_categories

  def index
    @project_count = Rails.cache.fetch('project_count', expires_in: 1.day) do
      Project.where(visible: true).count
    end
    @project_count_total = @project_count
    # Display the projects in increments of 50
    @project_count = (@project_count / 50).floor * 50

    @volunteer_count = Rails.cache.fetch('volunteer_count', expires_in: 1.day) do
      User.count
    end
    # Display the volunteers in increments of 100
    @volunteer_count = (@volunteer_count / 100).floor * 100
    @featured_projects = Project.where(visible: true, highlight: true).includes(:project_types, :skills, :volunteers).limit(3).order('RANDOM()')

    @projects_header = "#{CITY_NAME} Residents vs. COVID-19"
    @projects_subheader = "This is a #{CITY_NAME}-wide partnership platform, where #{CITY_NAME} residents can volunteer (in-person or remotely) and local non-profits and government can post volunteer needs. Let us unite and fight the pandemic together!"
  end

  private
    def projects_with_skills(category)
      Project.where(visible: true).find_each.filter { |proj|
        !(proj.skill_list & category[:project_types]).empty?
      }
    end

    def projects_with_locations(category)
      projects = Project.where(visible: true)
      if category[:project_types].length == 1
        projects = projects.where('location LIKE ?', '%' + category[:project_types][0] + '%')
      else
        projects = projects.where(location: category[:project_types])
      end
      projects
    end

    def relevant_projects(category)
      relevant_projects = projects_with_skills(category) + projects_with_locations(category)
      if category[:project_types].include? '(on site)'
        relevant_projects.filter! { |proj| not proj.skill_list.include? 'Access to car' }
      end
      relevant_projects = relevant_projects.sort_by { |project|
        project.highlight ? 0: 1 } # show highlighted projects first
      relevant_projects
    end

    def relevant_projects_count(category)
      relevant_projects = projects_with_skills(category) + projects_with_locations(category)
      relevant_projects.count
    end

    def hydrate_project_categories
      @project_categories = Settings.project_categories

      @project_categories.each do |category|
        category[:featured_projects] = Rails.cache.fetch("project_category_#{category[:slug]}_projects", expires_in: 1.hour) {
          relevant_projects(category).take 3
        }
        category[:projects_count] = Rails.cache.fetch("project_category_#{category[:slug]}_projects_count", expires_in: 1.hour) {
          relevant_projects_count(category)
        }
      end
    end
end
