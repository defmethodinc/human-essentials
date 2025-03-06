
require "rails_helper"

RSpec.describe RequestItem do
describe "#from_json", :phoenix do
  let(:organization) { create(:organization, :with_items) }
  let(:partner) { create(:partner, organization: organization) }
  let(:storage_location) { create(:storage_location, organization: organization) }
  let(:item) { create(:item, organization: organization) }
  let(:request) { create(:request, :with_item_requests, partner: partner, organization: organization) }
  let(:json) { { 'item_id' => item.id, 'quantity' => 5 } }
  let(:inventory) { Inventory.create(organization: organization) }

  it "creates a RequestItem from valid JSON input" do
    request_item = RequestItem.from_json(json, request)
    expect(request_item.item).to eq(item)
  end

  it "assigns the correct quantity from JSON input" do
    request_item = RequestItem.from_json(json, request)
    expect(request_item.quantity).to eq(5)
  end

  describe "when default storage location is present" do
    it "uses partner's default storage location" do
      allow(partner).to receive(:default_storage_location_id).and_return(storage_location.id)
      request_item = RequestItem.from_json(json, request)
      expect(request_item.storage_location).to eq(storage_location)
    end

    it "falls back to organization's default storage location" do
      allow(partner).to receive(:default_storage_location_id).and_return(nil)
      allow(organization).to receive(:default_storage_location).and_return(storage_location.id)
      request_item = RequestItem.from_json(json, request)
      expect(request_item.storage_location).to eq(storage_location)
    end
  end

  it "retrieves unit from item requests" do
    unit = request.item_requests.find { |item_request| item_request.item_id == item.id }&.request_unit
    request_item = RequestItem.from_json(json, request)
    expect(request_item.unit).to eq(unit)
  end

  describe "when inventory is provided" do
    it "calculates on hand quantity" do
      allow(inventory).to receive(:quantity_for).with(item_id: item.id).and_return(10)
      request_item = RequestItem.from_json(json, request, inventory)
      expect(request_item.on_hand).to eq(10)
    end

    it "calculates on hand for location" do
      allow(inventory).to receive(:quantity_for).with(storage_location: storage_location.id, item_id: item.id).and_return(5)
      request_item = RequestItem.from_json(json, request, inventory)
      expect(request_item.on_hand_for_location).to eq(5)
    end
  end

  describe "when location is found" do
    it "handles found location" do
      allow(StorageLocation).to receive(:find_by).with(id: storage_location.id).and_return(storage_location)
      request_item = RequestItem.from_json(json, request)
      expect(request_item.storage_location).to eq(storage_location)
    end

    it "handles location not found" do
      allow(StorageLocation).to receive(:find_by).with(id: storage_location.id).and_return(nil)
      request_item = RequestItem.from_json(json, request)
      expect(request_item.storage_location).to be_nil
    end
  end

  describe "when on hand for location is calculated" do
    it "handles positive on hand for location" do
      allow(inventory).to receive(:quantity_for).with(storage_location: storage_location.id, item_id: item.id).and_return(5)
      request_item = RequestItem.from_json(json, request, inventory)
      expect(request_item.on_hand_for_location).to eq(5)
    end

    it "handles non-positive on hand for location" do
      allow(inventory).to receive(:quantity_for).with(storage_location: storage_location.id, item_id: item.id).and_return(0)
      request_item = RequestItem.from_json(json, request, inventory)
      expect(request_item.on_hand_for_location).to eq('N/A')
    end
  end
end
describe '#initialize', :phoenix do
  let(:item) { Item.create(name: 'Test Item') }
  let(:quantity) { 10 }
  let(:unit) { 'kg' }
  let(:on_hand) { 50 }
  let(:on_hand_for_location) { 30 }

  it 'initializes with valid parameters' do
    request_item = RequestItem.new(item, quantity, unit, on_hand, on_hand_for_location)
    expect(request_item).to be_a(RequestItem)
  end

  describe 'when item is nil' do
    let(:item) { nil }

    it 'raises an error for nil item' do
      expect { RequestItem.new(item, quantity, unit, on_hand, on_hand_for_location) }.to raise_error(ArgumentError)
    end
  end

  describe 'when quantity is nil' do
    let(:quantity) { nil }

    it 'raises an error for nil quantity' do
      expect { RequestItem.new(item, quantity, unit, on_hand, on_hand_for_location) }.to raise_error(ArgumentError)
    end
  end

  describe 'when unit is nil' do
    let(:unit) { nil }

    it 'raises an error for nil unit' do
      expect { RequestItem.new(item, quantity, unit, on_hand, on_hand_for_location) }.to raise_error(ArgumentError)
    end
  end

  describe 'when on_hand is nil' do
    let(:on_hand) { nil }

    it 'raises an error for nil on_hand' do
      expect { RequestItem.new(item, quantity, unit, on_hand, on_hand_for_location) }.to raise_error(ArgumentError)
    end
  end

  describe 'when on_hand_for_location is nil' do
    let(:on_hand_for_location) { nil }

    it 'raises an error for nil on_hand_for_location' do
      expect { RequestItem.new(item, quantity, unit, on_hand, on_hand_for_location) }.to raise_error(ArgumentError)
    end
  end

  describe 'when parameters are of unexpected types' do
    let(:quantity) { 'ten' }

    it 'raises an error for unexpected type of quantity' do
      expect { RequestItem.new(item, quantity, unit, on_hand, on_hand_for_location) }.to raise_error(TypeError)
    end
  end
end
end
