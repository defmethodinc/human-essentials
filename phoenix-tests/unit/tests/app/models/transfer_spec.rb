
require "rails_helper"

RSpec.describe Transfer do
describe '.csv_export_headers', :phoenix do
  it 'returns the correct CSV headers' do
    expect(Transfer.csv_export_headers).to eq(['From', 'To', 'Comment', 'Total Moved'])
  end
end
describe '#csv_export_attributes', :phoenix do
  let(:organization) { create(:organization) }
  let(:from_location) { build(:storage_location, name: 'From Location', organization: organization) }
  let(:to_location) { build(:storage_location, name: 'To Location', organization: organization) }
  let(:line_item) { build(:line_item, quantity: 10, itemizable: transfer) }
  let(:transfer) { build(:transfer, from: from_location, to: to_location, comment: 'A comment', organization: organization, line_items: [line_item]) }

  it 'returns attributes when all values are present' do
    expect(transfer.csv_export_attributes).to eq(['From Location', 'To Location', 'A comment', 10])
  end

  describe 'when from.name is nil' do
    let(:from_location) { build(:storage_location, name: nil, organization: organization) }

    it 'handles nil from.name' do
      expect(transfer.csv_export_attributes).to eq([nil, 'To Location', 'A comment', 10])
    end
  end

  describe 'when to.name is nil' do
    let(:to_location) { build(:storage_location, name: nil, organization: organization) }

    it 'handles nil to.name' do
      expect(transfer.csv_export_attributes).to eq(['From Location', nil, 'A comment', 10])
    end
  end

  describe 'when comment is nil' do
    let(:transfer) { build(:transfer, from: from_location, to: to_location, comment: nil, organization: organization, line_items: [line_item]) }

    it 'defaults comment to none' do
      expect(transfer.csv_export_attributes).to eq(['From Location', 'To Location', 'none', 10])
    end
  end

  describe 'when line_items.total is nil' do
    let(:line_item) { build(:line_item, quantity: nil, itemizable: transfer) }

    it 'handles nil line_items.total' do
      expect(transfer.csv_export_attributes).to eq(['From Location', 'To Location', 'A comment', nil])
    end
  end

  describe 'when line_items.total is zero' do
    let(:line_item) { build(:line_item, quantity: 0, itemizable: transfer) }

    it 'handles zero line_items.total' do
      expect(transfer.csv_export_attributes).to eq(['From Location', 'To Location', 'A comment', 0])
    end
  end
end
describe "#storage_locations_belong_to_organization", :phoenix do
  let(:organization) { build(:organization) }
  let(:from_location) { build(:storage_location, organization: organization) }
  let(:to_location) { build(:storage_location, organization: organization) }
  let(:transfer) { build(:transfer, organization: organization, from: from_location, to: to_location) }

  it "does nothing if organization is nil" do
    transfer.organization = nil
    transfer.storage_locations_belong_to_organization
    expect(transfer.errors[:from]).to be_empty
    expect(transfer.errors[:to]).to be_empty
  end

  describe "when organization is present" do
    it "adds error if 'from' location does not belong to organization" do
      transfer.from = build(:storage_location)
      transfer.storage_locations_belong_to_organization
      expect(transfer.errors[:from]).to include("location must belong to organization")
    end

    it "does not add error if 'from' location belongs to organization" do
      transfer.storage_locations_belong_to_organization
      expect(transfer.errors[:from]).to be_empty
    end

    it "adds error if 'to' location does not belong to organization" do
      transfer.to = build(:storage_location)
      transfer.storage_locations_belong_to_organization
      expect(transfer.errors[:to]).to include("location must belong to organization")
    end

    it "does not add error if 'to' location belongs to organization" do
      transfer.storage_locations_belong_to_organization
      expect(transfer.errors[:to]).to be_empty
    end
  end
end
describe '#storage_locations_must_be_different', :phoenix do
  let(:organization) { create(:organization) }
  let(:from_location) { build(:storage_location, organization: organization) }
  let(:to_location) { build(:storage_location, organization: organization) }

  it 'does not add an error when organization is nil' do
    transfer = build(:transfer, organization: nil, from: from_location, to: to_location)
    transfer.storage_locations_must_be_different
    expect(transfer.errors[:to]).to be_empty
  end

  it 'does not add an error when to_id is nil' do
    transfer = build(:transfer, organization: organization, from: from_location, to: nil)
    transfer.storage_locations_must_be_different
    expect(transfer.errors[:to]).to be_empty
  end

  it 'adds an error when from_id is equal to to_id' do
    transfer = build(:transfer, organization: organization, from: from_location, to: from_location)
    transfer.storage_locations_must_be_different
    expect(transfer.errors[:to]).to include('location must be different than from location')
  end

  it 'does not add an error when from_id is not equal to to_id' do
    transfer = build(:transfer, organization: organization, from: from_location, to: to_location)
    transfer.storage_locations_must_be_different
    expect(transfer.errors[:to]).to be_empty
  end
end
describe '#from_storage_quantities', :phoenix do
  let(:organization) { create(:organization) }
  let(:from_location) { create(:storage_location, organization: organization) }
  let(:transfer) { build(:transfer, organization: organization, from: from_location) }

  context 'when organization is nil' do
    let(:transfer) { build(:transfer, organization: nil, from: from_location) }

    it 'does not add any errors' do
      expect { transfer.from_storage_quantities }.not_to change { transfer.errors[:from] }
    end
  end

  context 'when from is nil' do
    let(:transfer) { build(:transfer, organization: organization, from: nil) }

    it 'does not add any errors' do
      expect { transfer.from_storage_quantities }.not_to change { transfer.errors[:from] }
    end
  end

  describe 'when organization and from are not nil' do
    context 'when insufficient_items is empty' do
      before do
        allow(transfer).to receive(:insufficient_items).and_return([])
      end

      it 'does not add any errors' do
        expect { transfer.from_storage_quantities }.not_to change { transfer.errors[:from] }
      end
    end

    context 'when insufficient_items is not empty' do
      let(:item) { create(:item, organization: organization) }
      before do
        allow(transfer).to receive(:insufficient_items).and_return([item])
      end

      it 'adds an error for insufficient inventory' do
        expect { transfer.from_storage_quantities }.to change { transfer.errors[:from] }
          .from([])
          .to(include("location has insufficient inventory for #{item.name}"))
      end
    end
  end
end
describe "#insufficient_items", :phoenix do
  let(:organization) { create(:organization) }
  let(:inventory) { View::Inventory.new(organization.id) }
  let(:transfer) { build(:transfer, organization: organization) }

  it "returns an empty array when there are no line items" do
    expect(transfer.insufficient_items).to eq([])
  end

  context "when all line items have sufficient inventory" do
    let(:transfer) { build(:transfer, :with_items, organization: organization, item_quantity: 10) }
    before do
      allow(inventory).to receive(:quantity_for).and_return(20)
    end

    it "returns an empty array" do
      expect(transfer.insufficient_items).to eq([])
    end
  end

  context "when some line items have insufficient inventory" do
    let(:transfer) { build(:transfer, :with_items, organization: organization, item_quantity: 30) }
    before do
      allow(inventory).to receive(:quantity_for).and_return(20)
    end

    it "returns line items with insufficient inventory" do
      expect(transfer.insufficient_items.size).to eq(1)
    end
  end

  context "when all line items have insufficient inventory" do
    let(:transfer) { build(:transfer, :with_items, organization: organization, item_quantity: 30) }
    before do
      allow(inventory).to receive(:quantity_for).and_return(10)
    end

    it "returns all line items" do
      expect(transfer.insufficient_items.size).to eq(1)
    end
  end

  context "when handling edge cases" do
    context "like negative quantities" do
      let(:transfer) { build(:transfer, :with_items, organization: organization, item_quantity: -10) }
      before do
        allow(inventory).to receive(:quantity_for).and_return(0)
      end

      it "handles negative quantities" do
        expect(transfer.insufficient_items).to eq([])
      end
    end

    context "like zero quantities" do
      let(:transfer) { build(:transfer, :with_items, organization: organization, item_quantity: 0) }
      before do
        allow(inventory).to receive(:quantity_for).and_return(0)
      end

      it "handles zero quantities" do
        expect(transfer.insufficient_items).to eq([])
      end
    end
  end
end
end
