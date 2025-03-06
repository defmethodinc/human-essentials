
require "rails_helper"

RSpec.describe OrganizationStats do
describe '#initialize', :phoenix do
  let(:valid_organization) { build(:organization) }
  let(:nil_organization) { nil }
  let(:invalid_organization) { 'invalid_type' }

  it 'initializes with a valid organization' do
    organization_stats = OrganizationStats.new(valid_organization)
    expect(organization_stats.instance_variable_get(:@current_organization)).to eq(valid_organization)
  end

  it 'initializes with nil organization' do
    organization_stats = OrganizationStats.new(nil_organization)
    expect(organization_stats.instance_variable_get(:@current_organization)).to be_nil
  end

  it 'initializes with an invalid type' do
    organization_stats = OrganizationStats.new(invalid_organization)
    expect(organization_stats.instance_variable_get(:@current_organization)).to eq(invalid_organization)
  end
end
describe "#partners_added", :phoenix do
  let(:organization_stats_with_nil_partners) { OrganizationStats.new(partners: nil) }
  let(:organization_stats_with_empty_partners) { OrganizationStats.new(partners: []) }
  let(:organization_stats_with_partners) { OrganizationStats.new(partners: [Partner.new, Partner.new]) }

  it "returns 0 when partners is nil" do
    expect(organization_stats_with_nil_partners.partners_added).to eq(0)
  end

  it "returns 0 when partners is an empty array" do
    expect(organization_stats_with_empty_partners.partners_added).to eq(0)
  end

  it "returns the number of partners when partners is an array with elements" do
    expect(organization_stats_with_partners.partners_added).to eq(2)
  end
end
describe '#storage_locations_added', :phoenix do
  let(:organization_stats) { create(:organization_stats, storage_locations: storage_locations) }

  context 'when storage_locations is nil' do
    let(:storage_locations) { nil }

    it 'returns 0' do
      expect(organization_stats.storage_locations_added).to eq(0)
    end
  end

  context 'when storage_locations is an empty array' do
    let(:storage_locations) { [] }

    it 'returns 0' do
      expect(organization_stats.storage_locations_added).to eq(0)
    end
  end

  context 'when storage_locations is not empty' do
    let(:storage_locations) { build_list(:storage_location, 3) }

    it 'returns the number of storage locations' do
      expect(organization_stats.storage_locations_added).to eq(3)
    end
  end
end
describe '#donation_sites_added', :phoenix do
  let(:organization_stats_with_nil_sites) { OrganizationStats.new(donation_sites: nil) }
  let(:organization_stats_with_empty_sites) { OrganizationStats.new(donation_sites: []) }
  let(:organization_stats_with_sites) { OrganizationStats.new(donation_sites: [1, 2, 3]) }

  it 'returns 0 when donation_sites is nil' do
    expect(organization_stats_with_nil_sites.donation_sites_added).to eq(0)
  end

  it 'returns 0 when donation_sites is an empty array' do
    expect(organization_stats_with_empty_sites.donation_sites_added).to eq(0)
  end

  it 'returns the number of elements when donation_sites is not empty' do
    expect(organization_stats_with_sites.donation_sites_added).to eq(3)
  end
end
describe '#locations_with_inventory', :phoenix do
  let(:organization) { create(:organization) }
  let(:inventory) { View::Inventory.new(organization.id) }

  context 'when storage_locations is nil' do
    let(:storage_locations) { nil }

    it 'returns an empty array' do
      allow_any_instance_of(OrganizationStats).to receive(:storage_locations).and_return(storage_locations)
      expect(OrganizationStats.new.locations_with_inventory).to eq([])
    end
  end

  context 'when storage_locations is empty' do
    let(:storage_locations) { [] }

    it 'returns an empty array' do
      allow_any_instance_of(OrganizationStats).to receive(:storage_locations).and_return(storage_locations)
      expect(OrganizationStats.new.locations_with_inventory).to eq([])
    end
  end

  context 'when locations have positive inventory quantity' do
    let(:storage_locations) { build_list(:storage_location, 2, :with_items, organization: organization) }

    it 'returns locations with positive inventory quantity' do
      allow_any_instance_of(OrganizationStats).to receive(:storage_locations).and_return(storage_locations)
      allow(inventory).to receive(:quantity_for).and_return(10)
      expect(OrganizationStats.new.locations_with_inventory).to match_array(storage_locations)
    end
  end

  context 'when no locations have positive inventory quantity' do
    let(:storage_locations) { build_list(:storage_location, 2, organization: organization) }

    it 'returns an empty array' do
      allow_any_instance_of(OrganizationStats).to receive(:storage_locations).and_return(storage_locations)
      allow(inventory).to receive(:quantity_for).and_return(0)
      expect(OrganizationStats.new.locations_with_inventory).to eq([])
    end
  end
end
end
