
require "rails_helper"

RSpec.describe Adjustment do
describe "#storage_locations_adjusted_for", :phoenix do
  let(:organization) { create(:organization) }
  let(:storage_location_1) { create(:storage_location, organization: organization, name: 'Location A') }
  let(:storage_location_2) { create(:storage_location, organization: organization, name: 'Location B') }
  let(:discarded_storage_location) { create(:storage_location, organization: organization, discarded_at: Time.current) }

  it "returns non-discarded storage locations for the organization" do
    storage_location_1
    storage_location_2
    discarded_storage_location
    expect(Adjustment.storage_locations_adjusted_for(organization)).to match_array([storage_location_1, storage_location_2])
  end

  it "excludes discarded storage locations" do
    storage_location_1
    discarded_storage_location
    expect(Adjustment.storage_locations_adjusted_for(organization)).not_to include(discarded_storage_location)
  end

  it "returns an empty array when no storage locations exist" do
    expect(Adjustment.storage_locations_adjusted_for(organization)).to eq([])
  end

  it "returns storage locations sorted by name" do
    storage_location_1
    storage_location_2
    expect(Adjustment.storage_locations_adjusted_for(organization)).to eq([storage_location_1, storage_location_2].sort_by(&:name))
  end

  it "handles nil organization gracefully without error" do
    expect { Adjustment.storage_locations_adjusted_for(nil) }.not_to raise_error
  end

  it "returns an empty array for nil organization" do
    expect(Adjustment.storage_locations_adjusted_for(nil)).to eq([])
  end
end
describe '#split_difference', :phoenix do
  let(:adjustment_with_positive_quantities) { build(:adjustment, :with_items, item_quantity: 5) }
  let(:adjustment_with_non_positive_quantities) { build(:adjustment, :with_items, item_quantity: -5) }
  let(:adjustment_with_mixed_quantities) do
    adjustment = build(:adjustment)
    adjustment.line_items << build(:line_item, quantity: 5, itemizable: adjustment)
    adjustment.line_items << build(:line_item, quantity: -5, itemizable: adjustment)
    adjustment
  end
  let(:empty_adjustment) { build(:adjustment, line_items: []) }

  it 'returns only positive quantities in increasing_adjustment' do
    increasing_adjustment, _ = adjustment_with_positive_quantities.split_difference
    expect(increasing_adjustment.line_items.map(&:quantity)).to all(be > 0)
  end

  it 'returns empty decreasing_adjustment for positive quantities' do
    _, decreasing_adjustment = adjustment_with_positive_quantities.split_difference
    expect(decreasing_adjustment.line_items).to be_empty
  end

  it 'returns empty increasing_adjustment for non-positive quantities' do
    increasing_adjustment, _ = adjustment_with_non_positive_quantities.split_difference
    expect(increasing_adjustment.line_items).to be_empty
  end

  it 'returns only negative quantities in decreasing_adjustment' do
    _, decreasing_adjustment = adjustment_with_non_positive_quantities.split_difference
    expect(decreasing_adjustment.line_items.map(&:quantity)).to all(be < 0)
  end

  it 'correctly splits mixed quantities into increasing_adjustment' do
    increasing_adjustment, _ = adjustment_with_mixed_quantities.split_difference
    expect(increasing_adjustment.line_items.map(&:quantity)).to all(be > 0)
  end

  it 'correctly splits mixed quantities into decreasing_adjustment' do
    _, decreasing_adjustment = adjustment_with_mixed_quantities.split_difference
    expect(decreasing_adjustment.line_items.map(&:quantity)).to all(be < 0)
  end

  it 'returns empty adjustments for empty line_items' do
    increasing_adjustment, decreasing_adjustment = empty_adjustment.split_difference
    expect(increasing_adjustment.line_items).to be_empty
    expect(decreasing_adjustment.line_items).to be_empty
  end

  it 'modifies the quantity of line_items in decreasing_adjustment to negative' do
    _, decreasing_adjustment = adjustment_with_mixed_quantities.split_difference
    expect(decreasing_adjustment.line_items.map(&:quantity)).to all(be < 0)
  end
end
describe '.csv_export_headers', :phoenix do
  let(:expected_headers) { ["Created", "Organization", "Storage Location", "Comment", "Changes"] }

  it 'returns an array' do
    expect(Adjustment.csv_export_headers).to be_an(Array)
  end

  it 'contains the expected headers' do
    expect(Adjustment.csv_export_headers).to match_array(expected_headers)
  end

  it 'returns headers in the correct order' do
    expect(Adjustment.csv_export_headers).to eq(expected_headers)
  end
end
describe '#csv_export_attributes', :phoenix do
  let(:organization) { build(:organization, name: 'Test Organization') }
  let(:storage_location) { build(:storage_location, name: 'Test Location', organization: organization) }
  let(:line_item) { build(:line_item, :adjustment) }
  let(:adjustment) { build(:adjustment, organization: organization, storage_location: storage_location, comment: 'Test Comment', line_items: [line_item]) }

  it 'returns formatted created_at date' do
    expect(adjustment.csv_export_attributes[0]).to eq(adjustment.created_at.strftime('%F'))
  end

  it 'returns organization name' do
    expect(adjustment.csv_export_attributes[1]).to eq('Test Organization')
  end

  it 'returns storage location name' do
    expect(adjustment.csv_export_attributes[2]).to eq('Test Location')
  end

  it 'returns comment' do
    expect(adjustment.csv_export_attributes[3]).to eq('Test Comment')
  end

  it 'returns line items count' do
    expect(adjustment.csv_export_attributes[4]).to eq(1)
  end

  context 'when organization is nil' do
    let(:adjustment) { build(:adjustment, organization: nil, storage_location: storage_location, line_items: [line_item]) }

    it 'handles the nil organization case' do
      expect(adjustment.csv_export_attributes[1]).to be_nil
    end
  end

  context 'when storage_location is nil' do
    let(:adjustment) { build(:adjustment, organization: organization, storage_location: nil, line_items: [line_item]) }

    it 'handles the nil storage_location case' do
      expect(adjustment.csv_export_attributes[2]).to be_nil
    end
  end

  context 'when comment is nil' do
    let(:adjustment) { build(:adjustment, organization: organization, storage_location: storage_location, comment: nil, line_items: [line_item]) }

    it 'handles the nil comment case' do
      expect(adjustment.csv_export_attributes[3]).to be_nil
    end
  end

  context 'when line_items is empty' do
    let(:adjustment) { build(:adjustment, organization: organization, storage_location: storage_location, line_items: []) }

    it 'handles the empty line_items case' do
      expect(adjustment.csv_export_attributes[4]).to eq(0)
    end
  end

  context 'when created_at is nil' do
    let(:adjustment) { build(:adjustment, organization: organization, storage_location: storage_location, created_at: nil, line_items: [line_item]) }

    it 'handles the nil created_at case' do
      expect(adjustment.csv_export_attributes[0]).to be_nil
    end
  end
end
describe '#storage_locations_belong_to_organization', :phoenix do
  let(:organization) { build(:organization) }
  let(:storage_location) { build(:storage_location, organization: organization) }
  let(:adjustment) { build(:adjustment, organization: organization, storage_location: storage_location) }

  it 'returns early if organization is nil' do
    adjustment.organization = nil
    adjustment.storage_locations_belong_to_organization
    expect(adjustment.errors[:storage_location]).to be_empty
  end

  context 'when storage location belongs to the organization' do
    it 'does not add any errors' do
      adjustment.storage_locations_belong_to_organization
      expect(adjustment.errors[:storage_location]).to be_empty
    end
  end

  context 'when storage location does not belong to the organization' do
    let(:other_organization) { build(:organization) }
    let(:storage_location) { build(:storage_location, organization: other_organization) }

    it 'adds an error to storage_location' do
      adjustment.storage_locations_belong_to_organization
      expect(adjustment.errors[:storage_location]).to include('storage location must belong to organization')
    end
  end
end
end
