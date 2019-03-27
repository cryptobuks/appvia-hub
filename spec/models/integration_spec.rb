require 'rails_helper'

RSpec.describe Integration, type: :model do
  describe '#name' do
    it { is_expected.to validate_presence_of(:name) }
  end

  describe '#provider_id' do
    it { is_expected.to validate_presence_of(:provider_id) }
  end

  describe '#config' do
    it { is_expected.to validate_presence_of(:config) }

    context 'encryption, serialisation and persistence' do
      let :initial_config do
        { 'foo' => 'one', 'bar' => 'two' }
      end

      subject do
        create_mocked_integration config: initial_config
      end

      it 'persists and loads up the config from the db as expected' do
        subject.save!
        cp = Integration.find subject.id
        expect(cp.config).to be_a Hash
        expect(cp.config).to eq initial_config
      end

      it 'has encrypted the value in the database' do
        subject.save!
        cp = Integration.find subject.id
        expect(cp[:config]).to be_a String
        expect(cp[:config]).not_to be_blank
        expect(cp.config_before_type_cast).to be_a String
        expect(cp.config_before_type_cast).not_to be_blank
        expect(cp[:config]).not_to eq cp.config_before_type_cast
      end

      it 'updates as expected only if you assign the whole `config` again' do
        subject.save!
        cp = Integration.find subject.id
        cp.config = cp.config.merge('foo' => 'updated')
        expect(cp).to be_changed
        cp.save!
        expect(cp.reload.config['foo']).to eq 'updated'
      end

      it 'doesn\'t update if you update values in place' do
        # This is just down to how ActiveRecord works :(
        subject.save!
        cp = Integration.find subject.id
        cp.config['foo'] = 'updated'
        expect(cp).to be_changed # Says it's changed ...
        cp.save!
        expect(cp.reload.config).to eq initial_config # ... but hasn't actually updated it!
      end

      # TODO: when https://github.com/collectiveidea/audited/pull/485 is released
      # it 'redacts the config data from audits' do
      #   subject.save!
      #   audit = subject.audits.first
      #   expect(audit.action).to eq 'create'
      #   expect(audit.audited_changes['config']).to eq '[REDACTED]'
      # end
    end

    context 'JSON Schema validation' do
      let(:provider_id) { Integration.provider_ids.keys.first }

      let :schema do
        JsonSchema.parse!(
          'properties' => {
            'foo' => { 'type' => 'string' },
            'bar' => { 'type' => 'string' }
          },
          'required' => %w[foo bar]
        )
      end

      let :valid_config do
        { 'foo' => 'one', 'bar' => 'two' }
      end

      subject do
        build :integration, provider_id: provider_id
      end

      before do
        allow(PROVIDERS_REGISTRY).to receive(:config_schemas)
          .and_return(provider_id => schema)
      end

      context 'for a valid config hash' do
        it 'is a valid instance' do
          subject.config = valid_config
          expect(subject).to be_valid
        end
      end

      context 'for an invalid config hash' do
        it 'registers an error on the field' do
          subject.config = { 'foo' => 1 }
          expect(subject).not_to be_valid
          expect(subject.errors).to_not be_empty
          expect(subject.errors[:config]).to be_present
        end
      end

      context 'updating an existing config hash' do
        before do
          subject.config = valid_config
          subject.save!
        end

        context 'still with a valid config hash' do
          it 'updates as expected' do
            cp = Integration.find subject.id
            cp.config = cp.config.merge('foo' => 'updated')
            expect(cp).to be_valid
          end
        end

        context 'now with an invalid config hash' do
          it 'registers an error on the field' do
            cp = Integration.find subject.id
            cp.config = cp.config.merge('foo' => 1)
            expect(cp).not_to be_valid
            expect(cp.errors).to_not be_empty
            expect(cp.errors[:config]).to be_present
          end
        end
      end
    end
  end
end
