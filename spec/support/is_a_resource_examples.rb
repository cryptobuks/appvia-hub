module IsAResourceExamples
  RSpec.shared_examples 'is a Resource' do
    describe 'is a Resource' do
      let(:factory) { described_class.model_name.element.to_sym }

      let(:provider) { create_mocked_provider }

      subject { create factory, provider: provider }

      describe '#project' do
        it { is_expected.to belong_to(:project) }
        it { is_expected.to have_readonly_attribute(:project_id) }
      end

      describe '#provider' do
        it { is_expected.to belong_to(:provider).class_name('ConfiguredProvider') }
        it { is_expected.to have_readonly_attribute(:provider_id) }
      end

      describe '#status' do
        it { is_expected.to define_enum_for(:status).backed_by_column_of_type(:string) }
        it { is_expected.to validate_presence_of(:status) }

        it 'has a default value' do
          expect(described_class.new.status).to eq 'pending'
        end
      end

      describe '#name' do
        include_examples 'slugged_attribute',
          :name,
          presence: true,
          uniqueness: { scope: :provider_id },
          readonly: true

        describe 'uniqueness check' do
          let(:project) { create :project, name: 'project-1' }
          let(:other_project) { create :project, name: 'project-2' }

          let(:other_provider) { create_mocked_provider }

          let(:name) { 'foo' }
          let(:other_name) { 'bar' }

          before do
            create(
              factory,
              name: name,
              project: project,
              provider: provider
            )
          end

          it 'does not allow the same name for resources, for the same provider, in the same project' do
            other_resource = build(
              factory,
              name: name,
              project: project,
              provider: provider
            )

            expect(other_resource).not_to be_valid
            expect(other_resource.errors[:name].first).to eq 'has already been taken'
          end

          it 'allows different names for resources, for the same provider, in the same project' do
            other_resource = build(
              factory,
              name: other_name,
              project: project,
              provider: provider
            )

            expect(other_resource).to be_valid
          end

          it 'allows the same name for resources, for different providers, in the same project' do
            other_resource = build(
              factory,
              name: name,
              project: project,
              provider: other_provider
            )

            expect(other_resource).to be_valid
          end

          it 'allows the same name for resources, for the same provider, in different projects' do
            other_resource = build(
              factory,
              name: name,
              project: other_project,
              provider: provider
            )

            expect(other_resource).to be_valid
          end
        end

        describe '#build_name' do
          let(:project) { create :project, name: 'test-project' }

          it 'prefixes the name with the project slug' do
            resource = create(
              factory,
              name: 'foo',
              project: project,
              provider: provider
            )
            expect(resource.name).to eq "#{project.slug}_foo"
          end

          it 'can have the same value as the project slug' do
            resource = create(
              factory,
              name: project.slug,
              project: project,
              provider: provider
            )
            expect(resource.name).to eq project.slug
          end
        end
      end
    end
  end
end
