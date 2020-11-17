# Preview all emails at http://localhost:3000/rails/mailers/project_mailer
class ProjectMailerPreview < ActionMailer::Preview
  def new_volunteer
    user = User.first
    project = Project.last

    ProjectMailer.with(project: project, user: user).new_volunteer
  end

  def new_project
    project = Project.last
    ProjectMailer.with(project: project).new_project
  end

  def reminder
    project = Project.last
    ProjectMailer.with(project: project).reminder
  end

  def volunter_outreach
    user = User.first
    ProjectMailer.with(user: user).volunteer_outreach
  end
end
