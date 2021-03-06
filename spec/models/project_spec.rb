require 'rails_helper'

RSpec.describe Project, type: :model do
  let(:user) { FactoryBot.build(:user) }
  let(:project) { FactoryBot.build(:project, user: user) }

  it 'factory is valid' do
    user = FactoryBot.create(:user)
    project = FactoryBot.build(:project, user: user)
    expect(project).to be_valid
  end

  it 'is invalid without a user' do
    project = FactoryBot.build(:project, user: nil)
    expect(project).to_not be_valid
  end


  describe 'Group & Cover photo' do
    Settings.project_categories.each do |category|
      category['project_types'].to_a.each do |type|
        it "#{type} returns #{category.name}" do
          project.project_type_list.add(type)
          expect(project.category).to eq(category.name)
        end
      end
    end

    it 'project defaults to medical with no type' do
      expect(project.group).to eq('Community')
    end

    it 'returns correct cover photo' do
      project.project_type_list.add('Reduce spread')
      expect(project.cover_photo).to eq('/images/prevention-default.jpg')
    end

    it 'allow override of default cover photo' do
      expect(project.cover_photo('Test')).to eq('/images/test-default.jpg')
    end
  end
end
