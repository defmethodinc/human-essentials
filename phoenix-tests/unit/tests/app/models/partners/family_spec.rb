
require "rails_helper"

RSpec.describe Partners::Family do
describe '#create_authorized', :phoenix do
  let(:family) { build(:partners_family, guardian_first_name: guardian_first_name, guardian_last_name: guardian_last_name) }
  let(:guardian_first_name) { 'John' }
  let(:guardian_last_name) { 'Doe' }

  it 'increments the authorized family members count by 1' do
    expect { family.create_authorized }.to change { family.authorized_family_members.count }.by(1)
  end

  it 'sets the first name of the authorized family member correctly' do
    family.create_authorized
    authorized_member = family.authorized_family_members.last
    expect(authorized_member.first_name).to eq('John')
  end

  it 'sets the last name of the authorized family member correctly' do
    family.create_authorized
    authorized_member = family.authorized_family_members.last
    expect(authorized_member.last_name).to eq('Doe')
  end

  context 'when guardian_first_name is missing' do
    let(:guardian_first_name) { nil }

    it 'raises a validation error for missing first name' do
      expect { family.create_authorized }.to raise_error(ActiveRecord::RecordInvalid, /First name can't be blank/)
    end
  end

  context 'when guardian_last_name is missing' do
    let(:guardian_last_name) { nil }

    it 'raises a validation error for missing last name' do
      expect { family.create_authorized }.to raise_error(ActiveRecord::RecordInvalid, /Last name can't be blank/)
    end
  end
end
describe '#guardian_display_name', :phoenix do
  let(:family_with_full_name) { build(:partners_family, guardian_first_name: 'John', guardian_last_name: 'Doe') }
  let(:family_with_no_first_name) { build(:partners_family, guardian_first_name: nil, guardian_last_name: 'Doe') }
  let(:family_with_no_last_name) { build(:partners_family, guardian_first_name: 'John', guardian_last_name: nil) }
  let(:family_with_no_names) { build(:partners_family, guardian_first_name: nil, guardian_last_name: nil) }
  let(:family_with_empty_first_name) { build(:partners_family, guardian_first_name: '', guardian_last_name: 'Doe') }
  let(:family_with_empty_last_name) { build(:partners_family, guardian_first_name: 'John', guardian_last_name: '') }
  let(:family_with_empty_names) { build(:partners_family, guardian_first_name: '', guardian_last_name: '') }

  it 'returns full name when both first and last names are present' do
    expect(family_with_full_name.guardian_display_name).to eq('John Doe')
  end

  describe 'when first name is missing' do
    it 'returns only the last name' do
      expect(family_with_no_first_name.guardian_display_name).to eq('Doe')
    end
  end

  describe 'when last name is missing' do
    it 'returns only the first name' do
      expect(family_with_no_last_name.guardian_display_name).to eq('John')
    end
  end

  describe 'when both first and last names are missing' do
    it 'returns an empty string' do
      expect(family_with_no_names.guardian_display_name).to eq(' ')
    end
  end

  describe 'when first name is empty' do
    it 'returns only the last name' do
      expect(family_with_empty_first_name.guardian_display_name).to eq('Doe')
    end
  end

  describe 'when last name is empty' do
    it 'returns only the first name' do
      expect(family_with_empty_last_name.guardian_display_name).to eq('John')
    end
  end

  describe 'when both first and last names are empty' do
    it 'returns an empty string' do
      expect(family_with_empty_names.guardian_display_name).to eq(' ')
    end
  end
end
describe '#total_children_count', :phoenix do
  let(:family) { build(:partners_family, home_child_count: home_child_count, home_young_child_count: home_young_child_count) }

  context 'when both home_child_count and home_young_child_count are 0' do
    let(:home_child_count) { 0 }
    let(:home_young_child_count) { 0 }

    it 'returns 0' do
      expect(family.total_children_count).to eq(0)
    end
  end

  context 'when home_child_count is positive and home_young_child_count is 0' do
    let(:home_child_count) { 3 }
    let(:home_young_child_count) { 0 }

    it 'returns the correct count for positive home_child_count' do
      expect(family.total_children_count).to eq(3)
    end
  end

  context 'when home_child_count is 0 and home_young_child_count is positive' do
    let(:home_child_count) { 0 }
    let(:home_young_child_count) { 2 }

    it 'returns the correct count for positive home_young_child_count' do
      expect(family.total_children_count).to eq(2)
    end
  end

  context 'when both home_child_count and home_young_child_count are positive' do
    let(:home_child_count) { 2 }
    let(:home_young_child_count) { 3 }

    it 'returns the sum of both counts' do
      expect(family.total_children_count).to eq(5)
    end
  end

  context 'when handling negative values' do
    let(:home_child_count) { -1 }
    let(:home_young_child_count) { -1 }

    it 'returns the sum of negative values' do
      expect(family.total_children_count).to eq(-2)
    end
  end

  context 'when handling very large values' do
    let(:home_child_count) { 1_000_000 }
    let(:home_young_child_count) { 1_000_000 }

    it 'returns the sum of very large values' do
      expect(family.total_children_count).to eq(2_000_000)
    end
  end

  context 'when handling non-integer values' do
    let(:home_child_count) { 2.5 }
    let(:home_young_child_count) { 3.5 }

    it 'returns the sum of non-integer values' do
      expect(family.total_children_count).to eq(6.0)
    end
  end
end
describe "::csv_export_headers", :phoenix do
  let(:expected_headers) do
    %w[
      id guardian_first_name guardian_last_name guardian_zip_code guardian_county
      guardian_phone case_manager home_adult_count home_child_count home_young_child_count
      sources_of_income guardian_employed guardian_employment_type guardian_monthly_pay
      guardian_health_insurance comments created_at updated_at partner_id military archived
    ]
  end

  it "returns the correct headers" do
    expect(Partners::Family.csv_export_headers).to eq(expected_headers)
  end
end
describe '#csv_export_attributes', :phoenix do
  let(:family) { build(:partners_family) }

  it 'includes id' do
    expect(family.csv_export_attributes).to include(family.id)
  end

  it 'includes guardian_first_name' do
    expect(family.csv_export_attributes).to include(family.guardian_first_name)
  end

  it 'includes guardian_last_name' do
    expect(family.csv_export_attributes).to include(family.guardian_last_name)
  end

  it 'includes guardian_zip_code' do
    expect(family.csv_export_attributes).to include(family.guardian_zip_code)
  end

  it 'includes guardian_county' do
    expect(family.csv_export_attributes).to include(family.guardian_county)
  end

  it 'includes guardian_phone' do
    expect(family.csv_export_attributes).to include(family.guardian_phone)
  end

  it 'includes case_manager' do
    expect(family.csv_export_attributes).to include(family.case_manager)
  end

  it 'includes home_adult_count' do
    expect(family.csv_export_attributes).to include(family.home_adult_count)
  end

  it 'includes home_child_count' do
    expect(family.csv_export_attributes).to include(family.home_child_count)
  end

  it 'includes home_young_child_count' do
    expect(family.csv_export_attributes).to include(family.home_young_child_count)
  end

  it 'includes sources_of_income' do
    expect(family.csv_export_attributes).to include(family.sources_of_income)
  end

  it 'includes guardian_employed' do
    expect(family.csv_export_attributes).to include(family.guardian_employed)
  end

  it 'includes guardian_employment_type' do
    expect(family.csv_export_attributes).to include(family.guardian_employment_type)
  end

  it 'includes guardian_monthly_pay' do
    expect(family.csv_export_attributes).to include(family.guardian_monthly_pay)
  end

  it 'includes guardian_health_insurance' do
    expect(family.csv_export_attributes).to include(family.guardian_health_insurance)
  end

  it 'includes comments' do
    expect(family.csv_export_attributes).to include(family.comments)
  end

  it 'includes created_at' do
    expect(family.csv_export_attributes).to include(family.created_at)
  end

  it 'includes updated_at' do
    expect(family.csv_export_attributes).to include(family.updated_at)
  end

  it 'includes partner_id' do
    expect(family.csv_export_attributes).to include(family.partner_id)
  end

  it 'includes military' do
    expect(family.csv_export_attributes).to include(family.military)
  end

  it 'includes archived' do
    expect(family.csv_export_attributes).to include(family.archived)
  end
end
end
