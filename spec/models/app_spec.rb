require 'rails_helper'

RSpec.describe App, type: :model do
  subject { create :app }

  describe '#name' do
    it { is_expected.to validate_presence_of(:name) }
  end

  describe '#slug' do
    it { is_expected.to have_readonly_attribute(:slug) }

    it 'is readonly (using update!)' do
      original_slug = subject.slug
      subject.update! slug: 'updated-slug-should-not-work'
      expect(subject.reload.slug).to eq original_slug
    end

    it 'is readonly (using save!)' do
      original_slug = subject.slug
      subject.slug = 'updated-slug-should-not-work'
      subject.save!
      expect(subject.reload.slug).to eq original_slug
    end

    it { is_expected.to validate_presence_of(:slug) }

    it { is_expected.to validate_uniqueness_of(:slug) }
    it { is_expected.to have_db_index(:slug).unique(true) }

    it do
      is_expected.to allow_values(
        'f',
        'foo',
        'foo_bar',
        'foo-bar',
        'foo-1',
        'foo_1',
        'f1obar',
        'foo-bar5'
      ).for(:slug)
    end

    it do
      is_expected.not_to allow_values(
        'FOO_1',
        'fOO',
        'Foo',
        'foo bar',
        'foo 1',
        '1-foo',
        '1',
        '-foo',
        '_foo',
        'foo#1',
        'foo@1',
        '#1',
        '@1',
        'f123/bar'
      ).for(:slug)
    end
  end
end
