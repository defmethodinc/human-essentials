
require "rails_helper"

RSpec.describe StorageLocation do
describe "#items_inventoried", :phoenix do
  let(:organization) { create(:organization) }
  let(:inventory) { View::Inventory.new(organization.id) }
  let(:item1) { build(:item, name: "Apple", item_id: 1, organization: organization) }
  let(:item2) { build(:item, name: "Banana", item_id: 2, organization: organization) }
  let(:item3) { build(:item, name: "Apple", item_id: 1, organization: organization) }

  before do
    allow(inventory).to receive(:all_items).and_return([item1, item2, item3])
  end

  it "initializes a new inventory when none is provided" do
    result = StorageLocation.items_inventoried(organization)
    expect(result).to all(be_an(OpenStruct))
  end

  it "retrieves unique items from the inventory" do
    result = StorageLocation.items_inventoried(organization, inventory)
    expect(result.size).to eq(2)
  end

  it "ensures items are unique by item_id" do
    result = StorageLocation.items_inventoried(organization, inventory)
    expect(result.map(&:id)).to match_array([1, 2])
  end

  it "sorts items by name" do
    result = StorageLocation.items_inventoried(organization, inventory)
    expect(result.map(&:name)).to eq(["Apple", "Banana"])
  end

  it "maps items to OpenStruct with name and id" do
    result = StorageLocation.items_inventoried(organization, inventory)
    expect(result.first.name).to eq("Apple")
    expect(result.first.id).to eq(1)
  end

  context "when a custom inventory is provided" do
    let(:custom_inventory) { instance_double("View::Inventory") }

    before do
      allow(custom_inventory).to receive(:all_items).and_return([item1, item2])
    end

    it "uses the provided inventory instead of initializing a new one" do
      result = StorageLocation.items_inventoried(organization, custom_inventory)
      expect(result.size).to eq(2)
    end

    it "retrieves items sorted by name from custom inventory" do
      result = StorageLocation.items_inventoried(organization, custom_inventory)
      expect(result.map(&:name)).to eq(["Apple", "Banana"])
    end
  end
end
describe '#items', :phoenix do
  let(:organization) { create(:organization) }
  let(:storage_location) { create(:storage_location, organization: organization) }
  let(:item1) { create(:item, organization: organization, name: 'Apple') }
  let(:item2) { create(:item, organization: organization, name: 'Banana') }

  before do
    create(:inventory_item, storage_location: storage_location, item: item1, quantity: 10)
    create(:inventory_item, storage_location: storage_location, item: item2, quantity: 0)
  end

  it 'returns items with positive quantities' do
    expect(storage_location.items).to contain_exactly(item1)
  end

  it 'returns no items when there are no positive quantities' do
    InventoryItem.update_all(quantity: 0)
    expect(storage_location.items).to be_empty
  end

  describe 'when include_omitted is true' do
    before do
      allow(View::Inventory).to receive(:items_for_location).with(storage_location, include_omitted: true).and_return([item1, item2])
    end

    it 'includes active items not present in storage location' do
      expect(storage_location.items).to contain_exactly(item1, item2)
    end
  end

  describe 'when include_omitted is false' do
    before do
      allow(View::Inventory).to receive(:items_for_location).with(storage_location, include_omitted: false).and_return([item1])
    end

    it 'does not include active items not present in storage location' do
      expect(storage_location.items).to contain_exactly(item1)
    end
  end

  it 'returns an empty array when storage location is empty' do
    InventoryItem.where(storage_location: storage_location).destroy_all
    expect(storage_location.items).to be_empty
  end

  it 'returns items sorted by name' do
    create(:inventory_item, storage_location: storage_location, item: item2, quantity: 5)
    expect(storage_location.items).to eq([item1, item2])
  end
end
describe '#size', :phoenix do
  let(:storage_location) { create(:storage_location) }

  it 'calculates the total quantity of items for a location' do
    create(:storage_location, :with_items, item_count: 3, item_quantity: 5, organization: storage_location.organization)
    expect(storage_location.size).to eq(15)
  end

  context 'when there are no items' do
    it 'returns zero' do
      expect(storage_location.size).to eq(0)
    end
  end

  context 'when all items have zero quantity' do
    before do
      create(:storage_location, :with_items, item_count: 3, item_quantity: 0, organization: storage_location.organization)
    end

    it 'returns zero' do
      expect(storage_location.size).to eq(0)
    end
  end

  context 'when some items have zero quantity' do
    before do
      create(:storage_location, :with_items, item_count: 2, item_quantity: 5, organization: storage_location.organization)
      create(:storage_location, :with_items, item_count: 1, item_quantity: 0, organization: storage_location.organization)
    end

    it 'calculates the total quantity excluding zero quantities' do
      expect(storage_location.size).to eq(10)
    end
  end

  context 'when there is only one item' do
    before do
      create(:storage_location, :with_items, item_count: 1, item_quantity: 7, organization: storage_location.organization)
    end

    it 'returns the quantity of the single item' do
      expect(storage_location.size).to eq(7)
    end
  end

  context 'when items_for_location returns nil' do
    before do
      allow(View::Inventory).to receive(:items_for_location).and_return(nil)
    end

    it 'handles nil gracefully' do
      expect(storage_location.size).to eq(0)
    end
  end
end
describe '#item_total', :phoenix do
  let(:organization) { create(:organization) }
  let(:storage_location) { create(:storage_location, organization: organization) }
  let(:item) { create(:item, organization: organization) }
  let(:inventory) { View::Inventory.new(organization.id) }

  it 'returns the quantity of a specific item at the storage location' do
    allow(inventory).to receive(:quantity_for).with(storage_location: storage_location.id, item_id: item.id).and_return(50)
    expect(storage_location.item_total(item.id)).to eq(50)
  end

  it 'returns 0 if the item does not exist at the storage location' do
    allow(inventory).to receive(:quantity_for).with(storage_location: storage_location.id, item_id: item.id).and_return(0)
    expect(storage_location.item_total(item.id)).to eq(0)
  end

  it 'raises NoMethodError if the storage location does not exist' do
    expect { StorageLocation.new.item_total(item.id) }.to raise_error(NoMethodError)
  end

  it 'returns 0 if inventory is empty' do
    allow(inventory).to receive(:quantity_for).with(storage_location: storage_location.id, item_id: item.id).and_return(nil)
    expect(storage_location.item_total(item.id)).to eq(0)
  end

  it 'returns 0 if inventory contains nil values' do
    allow(inventory).to receive(:quantity_for).with(storage_location: storage_location.id, item_id: item.id).and_return(nil)
    expect(storage_location.item_total(item.id)).to eq(0)
  end

  it 'updates quantity after concurrent modifications to the inventory' do
    allow(inventory).to receive(:quantity_for).with(storage_location: storage_location.id, item_id: item.id).and_return(50)
    expect(storage_location.item_total(item.id)).to eq(50)
    allow(inventory).to receive(:quantity_for).with(storage_location: storage_location.id, item_id: item.id).and_return(30)
    expect(storage_location.item_total(item.id)).to eq(30)
  end
end
describe "#inventory_total_value_in_dollars", :phoenix do
  let(:storage_location) { create(:storage_location) }
  let(:inventory) { instance_double("View::Inventory", total_value_in_dollars: 100) }

  context "when inventory is provided" do
    it "calculates total value using provided inventory" do
      expect(inventory).to receive(:total_value_in_dollars).with(storage_location: storage_location.id)
      expect(storage_location.inventory_total_value_in_dollars(inventory)).to eq(100)
    end
  end

  context "when inventory is not provided" do
    before do
      allow(View::Inventory).to receive(:new).and_return(inventory)
    end

    it "calculates total value using default inventory" do
      expect(inventory).to receive(:total_value_in_dollars).with(storage_location: storage_location.id)
      expect(storage_location.inventory_total_value_in_dollars).to eq(100)
    end
  end

  context "when inventory is nil" do
    let(:inventory) { nil }

    it "does not raise error with nil inventory" do
      expect { storage_location.inventory_total_value_in_dollars(inventory) }.not_to raise_error
    end
  end

  it "calls total_value_in_dollars with storage_location id" do
    expect(inventory).to receive(:total_value_in_dollars).with(storage_location: storage_location.id)
    storage_location.inventory_total_value_in_dollars(inventory)
  end

  context "when inventory object is nil" do
    let(:inventory) { nil }

    it "does not raise error with nil inventory object" do
      expect { storage_location.inventory_total_value_in_dollars }.not_to raise_error
    end
  end
end
describe '#to_csv', :phoenix do
  let(:organization) { create(:organization, :with_items) }
  let(:storage_location) { create(:storage_location, organization: organization) }

  it 'generates CSV with correct headers' do
    csv_output = storage_location.to_csv
    expect(csv_output.lines.first.chomp).to eq('Quantity,DO NOT CHANGE ANYTHING IN THIS COLUMN')
  end

  describe 'when organization has items' do
    it 'includes all items from the organization' do
      csv_output = storage_location.to_csv
      organization.items.each do |item|
        expect(csv_output).to include(item.name)
      end
    end
  end

  describe 'when there are no items in the organization' do
    let(:organization) { create(:organization) }

    it 'generates CSV with only headers' do
      csv_output = storage_location.to_csv
      expect(csv_output).to eq("Quantity,DO NOT CHANGE ANYTHING IN THIS COLUMN\n")
    end
  end

  describe 'when the organization is nil' do
    let(:storage_location) { build(:storage_location, organization: nil) }

    it 'raises an error or handles gracefully' do
      expect { storage_location.to_csv }.to raise_error(NoMethodError)
    end
  end
end
describe "#import_csv", :phoenix do
  let(:organization) { create(:organization) }
  let(:valid_csv) { CSV.generate { |csv| csv << ["name", "address", "square_footage", "warehouse_type"]; csv << ["Location 1", "123 Main St", 1000, "Type A"] } }
  let(:invalid_csv) { CSV.generate { |csv| csv << ["name", "address", "square_footage", "warehouse_type"]; csv << [nil, "", nil, ""] } }
  let(:duplicate_csv) { CSV.generate { |csv| csv << ["name", "address", "square_footage", "warehouse_type"]; csv << ["Location 1", "123 Main St", 1000, "Type A"]; csv << ["Location 1", "123 Main St", 1000, "Type A"] } }

  it "imports all rows successfully" do
    expect { StorageLocation.import_csv(CSV.parse(valid_csv, headers: true), organization.id) }
      .to change { StorageLocation.count }.by(1)
  end

  it "raises error for invalid CSV data" do
    expect { StorageLocation.import_csv(CSV.parse(invalid_csv, headers: true), organization.id) }
      .to raise_error(ActiveRecord::RecordInvalid)
  end

  it "raises error on database save failure" do
    allow_any_instance_of(StorageLocation).to receive(:save!).and_raise(ActiveRecord::RecordNotSaved)
    expect { StorageLocation.import_csv(CSV.parse(valid_csv, headers: true), organization.id) }
      .to raise_error(ActiveRecord::RecordNotSaved)
  end

  it "does not change count for empty CSV" do
    empty_csv = CSV.generate { |csv| csv << ["name", "address", "square_footage", "warehouse_type"] }
    expect { StorageLocation.import_csv(CSV.parse(empty_csv, headers: true), organization.id) }
      .not_to change { StorageLocation.count }
  end

  it "assigns correct organization ID to imported locations" do
    StorageLocation.import_csv(CSV.parse(valid_csv, headers: true), organization.id)
    expect(StorageLocation.last.organization_id).to eq(organization.id)
  end

  it "imports only unique rows from CSV with duplicates" do
    expect { StorageLocation.import_csv(CSV.parse(duplicate_csv, headers: true), organization.id) }
      .to change { StorageLocation.count }.by(1)
  end
end
describe '#import_inventory', :phoenix do
  let(:organization) { create(:organization, :with_items) }
  let(:storage_location) { create(:storage_location, organization: organization) }
  let(:user) { create(:user, :organization_admin, organization: organization) }
  let(:item) { organization.items.first }
  let(:csv_content) { "quantity,item_name\n10,#{item.name}" }

  context 'when the storage location is not empty' do
    let(:storage_location) { create(:storage_location, :with_items, organization: organization) }

    it 'raises an InventoryAlreadyHasItems error' do
      expect {
        StorageLocation.import_inventory(csv_content, organization.id, storage_location.id)
      }.to raise_error(Errors::InventoryAlreadyHasItems)
    end
  end

  context 'when parsing the CSV file' do
    it 'builds line items' do
      adjustment = instance_double('Adjustment')
      allow(Adjustment).to receive(:new).and_return(adjustment)
      expect(adjustment).to receive(:line_items).and_return([])
      StorageLocation.import_inventory(csv_content, organization.id, storage_location.id)
    end

    it 'raises a MalformedCSVError for invalid CSV format' do
      invalid_csv_content = "quantity;item_name\n10;#{item.name}"
      expect {
        StorageLocation.import_inventory(invalid_csv_content, organization.id, storage_location.id)
      }.to raise_error(CSV::MalformedCSVError)
    end
  end

  context 'when creating an adjustment' do
    it 'calls the AdjustmentCreateService' do
      expect(AdjustmentCreateService).to receive(:new).and_call_original
      StorageLocation.import_inventory(csv_content, organization.id, storage_location.id)
    end

    it 'raises an error if adjustment creation fails' do
      allow_any_instance_of(AdjustmentCreateService).to receive(:call).and_return(false)
      expect {
        StorageLocation.import_inventory(csv_content, organization.id, storage_location.id)
      }.to raise_error(StandardError, 'Adjustment creation failed')
    end
  end

  context 'when all conditions are met' do
    it 'successfully imports inventory' do
      expect {
        StorageLocation.import_inventory(csv_content, organization.id, storage_location.id)
      }.to change { storage_location.size }.by(10)
    end
  end
end
describe "#validate_empty_inventory", :phoenix do
  let(:organization) { create(:organization) }
  let(:storage_location) { create(:storage_location, organization: organization) }

  context "when inventory is empty" do
    it "does not add an error" do
      storage_location.validate_empty_inventory
      expect(storage_location.errors[:base]).to be_empty
    end

    it "does not throw abort" do
      expect { storage_location.validate_empty_inventory }.not_to throw_symbol(:abort)
    end
  end

  context "when inventory is not empty" do
    let(:storage_location_with_items) { create(:storage_location, :with_items, organization: organization) }

    it "adds an error to base" do
      storage_location_with_items.validate_empty_inventory
      expect(storage_location_with_items.errors[:base]).to include("Cannot delete storage location containing inventory items with non-zero quantities")
    end

    it "throws abort" do
      expect { storage_location_with_items.validate_empty_inventory }.to throw_symbol(:abort)
    end
  end
end
describe '.csv_export_headers', :phoenix do
  let(:expected_headers) { ["Name", "Address", "Square Footage", "Warehouse Type", "Total Inventory"] }

  it 'returns the correct CSV export headers' do
    expect(StorageLocation.csv_export_headers).to eq(expected_headers)
  end
end
describe "#generate_csv_from_inventory", :phoenix do
  let(:storage_location) { create(:storage_location, :with_items, item_count: 3) }
  let(:inventory) { Inventory.create(storage_location: storage_location) }

  context "when storage_locations and inventory are empty" do
    let(:storage_locations) { [] }
    let(:inventory) { double(all_items: [], quantity_for: 0) }

    it "returns only headers" do
      csv = StorageLocation.generate_csv_from_inventory(storage_locations, inventory)
      expect(csv).to eq("Name,Address,Square Footage,Warehouse Type,Total Quantity\n")
    end
  end

  context "when generating CSV headers" do
    let(:storage_locations) { [storage_location] }
    let(:inventory) { double(all_items: [double(name: 'Item 1', item_id: 1)], quantity_for: 0) }

    it "includes item names in headers" do
      csv = StorageLocation.generate_csv_from_inventory(storage_locations, inventory)
      expect(csv).to include("Item 1")
    end
  end

  context "when calculating total quantity for each storage location" do
    let(:storage_locations) { [storage_location] }
    let(:inventory) { double(all_items: [], quantity_for: 10) }

    it "includes total quantity in CSV" do
      csv = StorageLocation.generate_csv_from_inventory(storage_locations, inventory)
      expect(csv).to include("10")
    end
  end

  context "when handling unique items and their quantities" do
    let(:storage_locations) { [storage_location] }
    let(:inventory) { double(all_items: [double(name: 'Item 1', item_id: 1)], quantity_for: 5) }

    it "includes item quantities in CSV" do
      csv = StorageLocation.generate_csv_from_inventory(storage_locations, inventory)
      expect(csv).to include("5")
    end
  end

  context "when normalizing CSV attributes" do
    let(:storage_locations) { [storage_location] }
    let(:inventory) { double(all_items: [double(name: 'Item 1', item_id: 1)], quantity_for: 5) }

    it "normalizes attributes correctly" do
      allow_any_instance_of(StorageLocation).to receive(:normalize_csv_attribute).and_return('Normalized')
      csv = StorageLocation.generate_csv_from_inventory(storage_locations, inventory)
      expect(csv).to include("Normalized")
    end
  end

  context "when handling multiple storage locations and items" do
    let(:storage_location_2) { create(:storage_location, :with_items, item_count: 2) }
    let(:storage_locations) { [storage_location, storage_location_2] }
    let(:inventory) { double(all_items: [double(name: 'Item 1', item_id: 1), double(name: 'Item 2', item_id: 2)], quantity_for: 5) }

    it "includes all storage locations and items in CSV" do
      csv = StorageLocation.generate_csv_from_inventory(storage_locations, inventory)
      expect(csv).to include(storage_location.name, storage_location_2.name, "Item 1", "Item 2")
    end
  end
end
describe '#empty_inventory?', :phoenix do
  let(:organization) { create(:organization) }
  let(:storage_location) { create(:storage_location, organization: organization) }
  let(:inventory) { View::Inventory.new(organization.id) }

  context 'when inventory is empty' do
    it 'returns true' do
      allow(inventory).to receive(:quantity_for).with(storage_location: storage_location.id).and_return(0)
      expect(storage_location.empty_inventory?).to be true
    end
  end

  context 'when inventory is not empty' do
    before do
      create(:item, organization: organization)
      create(:inventory_item, storage_location: storage_location, quantity: 10)
    end

    it 'returns false' do
      allow(inventory).to receive(:quantity_for).with(storage_location: storage_location.id).and_return(10)
      expect(storage_location.empty_inventory?).to be false
    end
  end

  context 'when there is an error during inventory retrieval' do
    it 'does not raise an error' do
      allow(inventory).to receive(:quantity_for).with(storage_location: storage_location.id).and_raise(StandardError)
      expect { storage_location.empty_inventory? }.not_to raise_error
    end
  end
end
end
