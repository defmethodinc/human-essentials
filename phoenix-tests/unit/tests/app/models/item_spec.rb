
require "rails_helper"

RSpec.describe Item do
describe '.barcoded_items', :phoenix do
  let(:organization) { create(:organization) }
  let(:item_category) { create(:item_category, organization: organization) }

  it 'returns empty when there are no items' do
    expect(Item.barcoded_items).to be_empty
  end

  context 'when there is a single item with no barcode items' do
    let!(:item) { create(:item, organization: organization, item_category: item_category) }

    it 'returns empty' do
      expect(Item.barcoded_items).to be_empty
    end
  end

  context 'when there are multiple items with no barcode items' do
    let!(:items) { create_list(:item, 3, organization: organization, item_category: item_category) }

    it 'returns empty' do
      expect(Item.barcoded_items).to be_empty
    end
  end

  context 'when there is a single item with multiple barcode items' do
    let!(:item) { create(:item, organization: organization, item_category: item_category) }
    let!(:barcode_items) { create_list(:barcode_item, 3, item: item) }

    it 'returns the item' do
      expect(Item.barcoded_items).to contain_exactly(item)
    end
  end

  context 'when there are multiple items each with multiple barcode items' do
    let!(:items) { create_list(:item, 3, organization: organization, item_category: item_category) }
    before do
      items.each { |item| create_list(:barcode_item, 2, item: item) }
    end

    it 'returns all items' do
      expect(Item.barcoded_items).to match_array(items)
    end
  end

  context 'when items have duplicate names' do
    let!(:item1) { create(:item, name: 'Duplicate', organization: organization, item_category: item_category) }
    let!(:item2) { create(:item, name: 'Duplicate', organization: organization, item_category: item_category) }

    it 'returns empty' do
      expect(Item.barcoded_items).to be_empty
    end
  end

  context 'when items have case-sensitive names' do
    let!(:item1) { create(:item, name: 'CaseSensitive', organization: organization, item_category: item_category) }
    let!(:item2) { create(:item, name: 'casesensitive', organization: organization, item_category: item_category) }

    it 'returns empty' do
      expect(Item.barcoded_items).to be_empty
    end
  end

  context 'when items have special characters in names' do
    let!(:item) { create(:item, name: 'Special!@#$', organization: organization, item_category: item_category) }

    it 'returns empty' do
      expect(Item.barcoded_items).to be_empty
    end
  end

  context 'when items have null or blank names' do
    let!(:item) { create(:item, name: nil, organization: organization, item_category: item_category) }

    it 'returns empty' do
      expect(Item.barcoded_items).to be_empty
    end
  end

  context 'performance with large data sets' do
    let!(:items) { create_list(:item, 1000, organization: organization, item_category: item_category) }

    it 'does not raise error' do
      expect { Item.barcoded_items }.not_to raise_error
    end
  end

  context 'database constraints' do
    it 'does not raise error' do
      expect { Item.barcoded_items }.not_to raise_error
    end
  end

  context 'concurrency' do
    it 'does not raise error' do
      expect { Item.barcoded_items }.not_to raise_error
    end
  end
end
describe '.barcodes_for', :phoenix do
  let(:organization) { Organization.try(:first) || create(:organization) }
  let(:item) { build(:item, organization: organization) }
  let(:barcode_item) { build(:barcode_item, barcodeable: item, organization: organization) }

  context 'when there are matching barcodes' do
    before do
      barcode_item.save
    end

    it 'returns the matching barcodes' do
      result = Item.barcodes_for(item)
      expect(result).to include(barcode_item)
    end
  end

  context 'when there are no matching barcodes' do
    it 'returns an empty collection' do
      result = Item.barcodes_for(item)
      expect(result).to be_empty
    end
  end

  context 'when the item is nil' do
    let(:item) { nil }

    it 'raises a NoMethodError' do
      expect { Item.barcodes_for(item) }.to raise_error(NoMethodError)
    end
  end

  context 'when the item is invalid' do
    let(:item) { build(:item, id: nil) }

    it 'raises a RecordNotFound error' do
      expect { Item.barcodes_for(item) }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
describe '.reactivate', :phoenix do
  let(:active_item) { create(:item, active: true) }
  let(:inactive_item) { create(:item, active: false) }
  let(:another_inactive_item) { create(:item, active: false) }

  it 'reactivates a single inactive item' do
    Item.reactivate(inactive_item.id)
    expect(inactive_item.reload.active).to eq(true)
  end

  describe 'when multiple items are reactivated' do
    it 'reactivates all specified inactive items' do
      Item.reactivate([inactive_item.id, another_inactive_item.id])
      expect(inactive_item.reload.active).to eq(true)
      expect(another_inactive_item.reload.active).to eq(true)
    end
  end

  describe 'when given an empty array' do
    it 'does not change the active status of any items' do
      expect { Item.reactivate([]) }.not_to change { Item.where(active: true).count }
    end
  end

  describe 'when given nil input' do
    it 'does not change the active status of any items' do
      expect { Item.reactivate(nil) }.not_to change { Item.where(active: true).count }
    end
  end

  describe 'when given a mix of valid and invalid item IDs' do
    it 'reactivates only the valid inactive items' do
      Item.reactivate([inactive_item.id, 9999]) # assuming 9999 is an invalid ID
      expect(inactive_item.reload.active).to eq(true)
    end
  end

  describe 'when all item IDs are invalid' do
    it 'does not change the active status of any items' do
      expect { Item.reactivate([9999, 8888]) }.not_to change { Item.where(active: true).count }
    end
  end
end
describe "#has_inventory?", :phoenix do
  let(:item) { build(:item) }

  it "returns false when inventory is nil" do
    inventory = nil
    expect(item.has_inventory?(inventory)).to be_falsey
  end

  context "when inventory is not nil" do
    let(:inventory) { double("Inventory") }

    before do
      allow(inventory).to receive(:quantity_for).with(item_id: item.id).and_return(quantity)
    end

    context "with positive quantity" do
      let(:quantity) { 5 }
      it "returns true for positive quantity" do
        expect(item.has_inventory?(inventory)).to be_truthy
      end
    end

    context "with zero quantity" do
      let(:quantity) { 0 }
      it "returns false for zero quantity" do
        expect(item.has_inventory?(inventory)).to be_falsey
      end
    end

    context "with negative quantity" do
      let(:quantity) { -1 }
      it "returns false for negative quantity" do
        expect(item.has_inventory?(inventory)).to be_falsey
      end
    end

    context "with nil quantity" do
      let(:quantity) { nil }
      it "returns false for nil quantity" do
        expect(item.has_inventory?(inventory)).to be_falsey
      end
    end
  end
end
describe '#in_request?', :phoenix do
  let(:item) { create(:item) }

  context 'when there is a request associated with the item' do
    before do
      allow(Request).to receive(:by_request_item_id).with(item.id).and_return(double('ActiveRecord::Relation', exists?: true))
    end

    it 'returns true' do
      expect(item.in_request?).to be true
    end
  end

  context 'when there is no request associated with the item' do
    before do
      allow(Request).to receive(:by_request_item_id).with(item.id).and_return(double('ActiveRecord::Relation', exists?: false))
    end

    it 'returns false' do
      expect(item.in_request?).to be false
    end
  end
end
describe '#is_in_kit?', :phoenix do
  let(:organization) { create(:organization) }
  let(:item) { create(:item, organization: organization) }
  let(:kit_with_item) { create(:kit, organization: organization, line_items: [build(:line_item, item: item)]) }
  let(:kit_without_item) { create(:kit, organization: organization) }

  context 'when kits are provided' do
    it 'returns false when kits is an empty array' do
      kits = []
      expect(item.is_in_kit?(kits)).to be_falsey
    end

    it 'returns true when kits contain a kit with the item' do
      kits = [kit_with_item]
      expect(item.is_in_kit?(kits)).to be_truthy
    end

    it 'returns false when kits do not contain a kit with the item' do
      kits = [kit_without_item]
      expect(item.is_in_kit?(kits)).to be_falsey
    end
  end

  context 'when kits are not provided' do
    before do
      allow(organization).to receive(:kits).and_return(kits)
    end

    context 'when the organization has no active kits' do
      let(:kits) { [] }

      it 'returns false' do
        expect(item.is_in_kit?).to be_falsey
      end
    end

    context 'when active kits do not contain the item' do
      let(:kits) { [kit_without_item] }

      it 'returns false' do
        expect(item.is_in_kit?).to be_falsey
      end
    end

    context 'when at least one active kit contains the item' do
      let(:kits) { [kit_with_item] }

      it 'returns true' do
        expect(item.is_in_kit?).to be_truthy
      end
    end
  end
end
describe '#can_delete?', :phoenix do
  let(:organization) { create(:organization) }
  let(:item) { build(:item, organization: organization, barcode_count: barcode_count) }
  let(:barcode_count) { 0 }
  let(:line_items) { [] }
  let(:in_request) { false }

  before do
    allow(item).to receive(:line_items).and_return(line_items)
    allow(item).to receive(:in_request?).and_return(in_request)
    allow(item).to receive(:can_deactivate_or_delete?).and_return(can_deactivate_or_delete)
  end

  context 'when can_deactivate_or_delete? is true' do
    let(:can_deactivate_or_delete) { true }

    context 'and line_items is empty' do
      let(:line_items) { [] }

      context 'and barcode_count is not positive' do
        let(:barcode_count) { 0 }

        context 'and not in_request' do
          let(:in_request) { false }

          it 'returns true when all conditions are met' do
            expect(item.can_delete?).to eq(true)
          end
        end

        context 'and in_request' do
          let(:in_request) { true }

          it 'returns false when in_request is true' do
            expect(item.can_delete?).to eq(false)
          end
        end
      end

      context 'and barcode_count is positive' do
        let(:barcode_count) { 1 }

        it 'returns false when barcode_count is positive' do
          expect(item.can_delete?).to eq(false)
        end
      end
    end

    context 'and line_items is not empty' do
      let(:line_items) { [double('LineItem')] }

      it 'returns false when line_items is not empty' do
        expect(item.can_delete?).to eq(false)
      end
    end
  end

  context 'when can_deactivate_or_delete? is false' do
    let(:can_deactivate_or_delete) { false }

    it 'returns false when can_deactivate_or_delete? is false' do
      expect(item.can_delete?).to eq(false)
    end
  end
end
describe '#can_deactivate_or_delete?', :phoenix do
  let(:organization) { create(:organization) }
  let(:inventory) { instance_double('View::Inventory', organization_id: organization.id) }
  let(:item_with_inventory_and_kit) { create(:item, organization: organization, kit: create(:kit), active: true) }
  let(:item_with_inventory_no_kit) { create(:item, organization: organization, kit: nil, active: true) }
  let(:item_no_inventory_with_kit) { build(:item, organization: organization, kit: create(:kit), active: true) }
  let(:item_no_inventory_no_kit) { build(:item, organization: organization, kit: nil, active: true) }

  before do
    allow(item_with_inventory_and_kit).to receive(:has_inventory?).with(inventory).and_return(true)
    allow(item_with_inventory_no_kit).to receive(:has_inventory?).with(inventory).and_return(true)
    allow(item_no_inventory_with_kit).to receive(:has_inventory?).with(inventory).and_return(false)
    allow(item_no_inventory_no_kit).to receive(:has_inventory?).with(inventory).and_return(false)

    allow(item_with_inventory_and_kit).to receive(:is_in_kit?).and_return(true)
    allow(item_with_inventory_no_kit).to receive(:is_in_kit?).and_return(false)
    allow(item_no_inventory_with_kit).to receive(:is_in_kit?).and_return(true)
    allow(item_no_inventory_no_kit).to receive(:is_in_kit?).and_return(false)
  end

  it 'returns false when the item has inventory and is part of a kit' do
    expect(item_with_inventory_and_kit.can_deactivate_or_delete?(inventory)).to eq(false)
  end

  it 'returns false when the item has inventory and is not part of a kit' do
    expect(item_with_inventory_no_kit.can_deactivate_or_delete?(inventory)).to eq(false)
  end

  it 'returns false when the item does not have inventory and is part of a kit' do
    expect(item_no_inventory_with_kit.can_deactivate_or_delete?(inventory)).to eq(false)
  end

  it 'returns true when the item does not have inventory and is not part of a kit' do
    expect(item_no_inventory_no_kit.can_deactivate_or_delete?(inventory)).to eq(true)
  end
end
describe '#validate_destroy', :phoenix do
  let(:item) { build(:item, can_delete: can_delete) }

  context 'when can_delete? returns true' do
    let(:can_delete) { true }

    it 'does not add errors to the base' do
      item.validate_destroy
      expect(item.errors[:base]).to be_empty
    end

    it 'does not abort the operation' do
      expect(item).not_to receive(:throw).with(:abort)
      item.validate_destroy
    end
  end

  context 'when can_delete? returns false' do
    let(:can_delete) { false }

    it 'adds an error to the base' do
      item.validate_destroy
      expect(item.errors[:base]).to include('Cannot delete item - it has already been used!')
    end

    it 'aborts the operation' do
      expect(item).to receive(:throw).with(:abort)
      item.validate_destroy
    end
  end
end
describe '#deactivate!', :phoenix do
  let(:organization) { create(:organization) }
  let(:item) { build(:item, organization: organization, kit: kit, active: true) }
  let(:kit) { nil }

  it 'raises an error when cannot deactivate or delete' do
    allow(item).to receive(:can_deactivate_or_delete?).and_return(false)
    expect { item.deactivate! }.to raise_error('Cannot deactivate item - it is in a storage location or kit!')
  end

  context 'when can deactivate or delete' do
    before do
      allow(item).to receive(:can_deactivate_or_delete?).and_return(true)
    end

    context 'and item is part of a kit' do
      let(:kit) { build(:kit) }

      it 'deactivates the kit' do
        expect(kit).to receive(:deactivate)
        item.deactivate!
      end
    end

    context 'and item is not part of a kit' do
      let(:kit) { nil }

      it 'deactivates the item' do
        expect(item).to receive(:update!).with(active: false)
        item.deactivate!
      end
    end
  end
end
describe '#other?', :phoenix do
  let(:item_with_other_key) { build(:item, partner_key: 'other') }
  let(:item_with_different_key) { build(:item, partner_key: 'different') }

  it 'returns true when partner_key is "other"' do
    expect(item_with_other_key.other?).to eq(true)
  end

  it 'returns false when partner_key is not "other"' do
    expect(item_with_different_key.other?).to eq(false)
  end
end
describe ".gather_items", :phoenix do
  let(:organization) { create(:organization) }
  let(:item) { create(:item, organization: organization) }
  let(:barcode_item) { create(:barcode_item, organization: organization, barcodeable: item) }

  context "when global is true" do
    let(:global) { true }

    it "returns items with barcodeable_id from all barcode_items" do
      allow(organization.barcode_items).to receive(:all).and_return([barcode_item])
      expect(Item.gather_items(organization, global)).to contain_exactly(item)
    end
  end

  context "when global is false" do
    let(:global) { false }

    it "returns items with barcodeable_id from barcode_items" do
      allow(organization.barcode_items).to receive(:pluck).with(:barcodeable_id).and_return([item.id])
      expect(Item.gather_items(organization, global)).to contain_exactly(item)
    end
  end

  context "when current_organization has no barcode_items" do
    let(:organization) { create(:organization) }

    it "returns an empty collection" do
      allow(organization.barcode_items).to receive(:pluck).with(:barcodeable_id).and_return([])
      expect(Item.gather_items(organization, false)).to be_empty
    end
  end
end
describe '#to_i', :phoenix do
  let(:item) { build(:item) }

  it 'returns the id as an integer' do
    expect(item.to_i).to eq(item.id)
  end

  describe 'when id is nil' do
    let(:item) { build(:item, id: nil) }

    it 'returns nil when id is nil' do
      expect(item.to_i).to eq(nil)
    end
  end

  describe 'when id is a valid integer' do
    let(:item) { build(:item, id: 123) }

    it 'returns the correct integer value for a valid id' do
      expect(item.to_i).to eq(123)
    end
  end

  describe 'when id is an edge case value' do
    let(:item) { build(:item, id: 0) }

    it 'returns 0 for an id of 0' do
      expect(item.to_i).to eq(0)
    end
  end
end
describe '#to_h', :phoenix do
  let(:item) { build(:item, name: item_name, id: item_id) }

  it 'returns a hash with name and item_id' do
    expect(item.to_h).to eq({ name: item_name, item_id: item_id })
  end

  context 'when name is nil' do
    let(:item_name) { nil }
    let(:item_id) { 1 }

    it 'returns a hash with nil name' do
      expect(item.to_h).to eq({ name: nil, item_id: item_id })
    end
  end

  context 'when id is nil' do
    let(:item_name) { 'Sample Item' }
    let(:item_id) { nil }

    it 'returns a hash with nil item_id' do
      expect(item.to_h).to eq({ name: item_name, item_id: nil })
    end
  end

  context 'when both name and id are nil' do
    let(:item_name) { nil }
    let(:item_id) { nil }

    it 'returns a hash with nil values' do
      expect(item.to_h).to eq({ name: nil, item_id: nil })
    end
  end
end
describe '.csv_export_headers', :phoenix do
  it 'returns an array with the correct headers' do
    expect(Item.csv_export_headers).to eq(["Name", "Barcodes", "Base Item", "Quantity"])
  end
end
describe '#generate_csv_from_inventory', :phoenix do
  let(:organization) { create(:organization) }
  let(:base_item) { create(:base_item, organization: organization) }
  let(:items) { build_list(:item, 3, organization: organization, base_item: base_item) }
  let(:inventory) { instance_double('Inventory') }

  before do
    allow(inventory).to receive(:quantity_for).and_return(10)
  end

  it 'generates CSV successfully with valid items and inventory' do
    csv = Item.generate_csv_from_inventory(items, inventory)
    expect(csv).to include(Item.csv_export_headers.join(','))
  end

  it 'includes item names in CSV' do
    csv = Item.generate_csv_from_inventory(items, inventory)
    items.each do |item|
      expect(csv).to include(item.name)
    end
  end

  it 'includes item barcode counts in CSV' do
    csv = Item.generate_csv_from_inventory(items, inventory)
    items.each do |item|
      expect(csv).to include(item.barcode_count.to_s)
    end
  end

  it 'includes base item names in CSV' do
    csv = Item.generate_csv_from_inventory(items, inventory)
    items.each do |item|
      expect(csv).to include(item.base_item.name)
    end
  end

  it 'includes item quantities in CSV' do
    csv = Item.generate_csv_from_inventory(items, inventory)
    items.each do |item|
      expect(csv).to include('10')
    end
  end

  context 'when items list is empty' do
    let(:items) { [] }

    it 'generates CSV with only headers' do
      csv = Item.generate_csv_from_inventory(items, inventory)
      expect(csv).to eq(Item.csv_export_headers.join(',') + "\n")
    end
  end

  context 'when items have missing attributes' do
    let(:items) { build_list(:item, 3, organization: organization, base_item: nil) }

    it 'handles missing base item names gracefully' do
      csv = Item.generate_csv_from_inventory(items, inventory)
      items.each do |item|
        expect(csv).to include(Item.normalize_csv_attribute(item.base_item&.name))
      end
    end
  end

  context 'when inventory has missing quantities for some items' do
    before do
      allow(inventory).to receive(:quantity_for).and_return(nil)
    end

    it 'handles missing quantities gracefully' do
      csv = Item.generate_csv_from_inventory(items, inventory)
      items.each do |item|
        expect(csv).to include(Item.normalize_csv_attribute(nil))
      end
    end
  end

  it 'includes correct CSV headers' do
    csv = Item.generate_csv_from_inventory(items, inventory)
    expect(csv.lines.first.chomp).to eq(Item.csv_export_headers.join(','))
  end

  it 'normalizes CSV attributes for item names' do
    csv = Item.generate_csv_from_inventory(items, inventory)
    items.each do |item|
      expect(csv).to include(Item.normalize_csv_attribute(item.name))
    end
  end

  it 'normalizes CSV attributes for barcode counts' do
    csv = Item.generate_csv_from_inventory(items, inventory)
    items.each do |item|
      expect(csv).to include(Item.normalize_csv_attribute(item.barcode_count))
    end
  end
end
describe '#default_quantity', :phoenix do
  let(:item_with_distribution_quantity) { build(:item, distribution_quantity: 30) }
  let(:item_without_distribution_quantity) { build(:item, distribution_quantity: nil) }

  it 'returns the distribution_quantity when it is present' do
    expect(item_with_distribution_quantity.default_quantity).to eq(30)
  end

  it 'returns the default value of 50 when distribution_quantity is not present' do
    expect(item_without_distribution_quantity.default_quantity).to eq(50)
  end
end
describe "#sync_request_units!", :phoenix do
  let(:organization) { create(:organization) }
  let(:item) { create(:item, organization: organization) }
  let(:existing_request_unit) { organization.request_units.create!(name: "Existing Unit") }
  let(:new_request_unit_name) { "New Unit" }

  it "clears existing request_units" do
    item.request_units << existing_request_unit
    item.sync_request_units!([])
    expect(item.request_units).to be_empty
  end

  context "when unit_ids is empty" do
    it "does not create any request_units" do
      item.sync_request_units!([])
      expect(item.request_units).to be_empty
    end
  end

  context "when unit_ids contains valid IDs" do
    let(:valid_unit) { organization.request_units.create!(name: new_request_unit_name) }

    it "creates request_units with the correct names" do
      item.sync_request_units!([valid_unit.id])
      expect(item.request_units.pluck(:name)).to include(new_request_unit_name)
    end
  end

  context "when no matching request_units in organization" do
    it "does not create any request_units" do
      item.sync_request_units!([999]) # Assuming 999 is a non-existent ID
      expect(item.request_units).to be_empty
    end
  end
end
describe '#update_associated_kit_name', :phoenix do
  let(:organization) { create(:organization) }
  let(:kit) { build(:kit, name: 'Old Kit Name') }
  let(:item) { build(:item, name: 'New Item Name', kit: kit, organization: organization) }

  it 'updates the kit name to match the item name' do
    item.update_associated_kit_name
    expect(kit.name).to eq('New Item Name')
  end

  context 'when kit is nil' do
    let(:item) { build(:item, name: 'New Item Name', kit: nil, organization: organization) }

    it 'does not change the kit name' do
      expect { item.update_associated_kit_name }.not_to change { kit.name }
    end
  end

  context 'when update fails due to validation errors' do
    before do
      allow(kit).to receive(:update).and_return(false)
    end

    it 'returns false indicating failure' do
      expect(item.update_associated_kit_name).to be_falsey
    end
  end
end
end
