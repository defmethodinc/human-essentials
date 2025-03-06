
require "rails_helper"

RSpec.describe Partners::Child do
describe '#display_name', :phoenix do
  let(:child_with_full_name) { build(:partners_child, first_name: 'John', last_name: 'Doe') }
  let(:child_with_first_name_only) { build(:partners_child, first_name: 'John', last_name: nil) }
  let(:child_with_last_name_only) { build(:partners_child, first_name: nil, last_name: 'Doe') }
  let(:child_with_no_name) { build(:partners_child, first_name: nil, last_name: nil) }

  it 'returns full name when both first_name and last_name are present' do
    expect(child_with_full_name.display_name).to eq('John Doe')
  end

  describe 'when first_name is present but last_name is nil' do
    it 'returns only first_name with trailing space' do
      expect(child_with_first_name_only.display_name).to eq('John ')
    end
  end

  describe 'when last_name is present but first_name is nil' do
    it 'returns only last_name with leading space' do
      expect(child_with_last_name_only.display_name).to eq(' Doe')
    end
  end

  describe 'when both first_name and last_name are nil' do
    it 'returns a single space' do
      expect(child_with_no_name.display_name).to eq(' ')
    end
  end
end
describe '.csv_export_headers', :phoenix do
  it 'returns the correct CSV headers' do
    expected_headers = %w[
      id first_name last_name date_of_birth gender child_lives_with race agency_child_id
      health_insurance comments created_at updated_at guardian_last_name guardian_first_name requested_items active archived
    ]
    expect(Partners::Child.csv_export_headers).to eq(expected_headers)
  end
end
describe '#csv_export_attributes', :phoenix do
  let(:family) { build(:partners_family, guardian_first_name: 'John', guardian_last_name: 'Doe') }
  let(:requested_item) { build(:item, name: 'Diapers') }
  let(:child_with_family) { build(:partners_child, family: family, requested_items: [requested_item]) }
  let(:child_without_family) { build(:partners_child, family: nil, requested_items: [requested_item]) }
  let(:child_with_no_requested_items) { build(:partners_child, requested_items: []) }

  it 'includes basic attributes' do
    expect(child_with_family.csv_export_attributes).to include(
      child_with_family.id,
      child_with_family.first_name,
      child_with_family.last_name,
      child_with_family.date_of_birth,
      child_with_family.gender,
      child_with_family.child_lives_with,
      child_with_family.race,
      child_with_family.agency_child_id,
      child_with_family.health_insurance,
      child_with_family.comments,
      child_with_family.created_at,
      child_with_family.updated_at
    )
  end

  describe 'when family association is present' do
    it 'includes guardian last name' do
      expect(child_with_family.csv_export_attributes).to include(family.guardian_last_name)
    end

    it 'includes guardian first name' do
      expect(child_with_family.csv_export_attributes).to include(family.guardian_first_name)
    end
  end

  describe 'when family association is nil' do
    it 'handles missing guardian last name gracefully' do
      expect(child_without_family.csv_export_attributes).to include(nil)
    end

    it 'handles missing guardian first name gracefully' do
      expect(child_without_family.csv_export_attributes).to include(nil)
    end
  end

  describe 'when requested_items are present' do
    it 'joins requested item names with a comma' do
      expect(child_with_family.csv_export_attributes).to include('Diapers')
    end
  end

  describe 'when requested_items are empty' do
    it 'handles empty requested items gracefully' do
      expect(child_with_no_requested_items.csv_export_attributes).to include('')
    end
  end

  it 'includes active attribute' do
    expect(child_with_family.csv_export_attributes).to include(child_with_family.active)
  end

  it 'includes archived attribute' do
    expect(child_with_family.csv_export_attributes).to include(child_with_family.archived)
  end
end
end
