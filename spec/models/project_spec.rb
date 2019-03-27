require 'rails_helper'

RSpec.describe Project, type: :model do
  subject { create :project }

  describe '#name' do
    it { is_expected.to validate_presence_of(:name) }
  end

  describe '#slug' do
    include_examples 'slugged_attribute',
      :slug,
      presence: true,
      uniqueness: true,
      readonly: true
  end
end
