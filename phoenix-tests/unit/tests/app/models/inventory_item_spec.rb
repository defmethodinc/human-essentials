
require "rails_helper"

RSpec.describe InventoryItem do
describe '#to_h', :phoenix do
  let(:item) { build(:item, name: item_name) }
  let(:inventory_item) { build(:inventory_item, item: item, item_id: item_id, quantity: quantity) }
  let(:item_id) { 1 }
  let(:quantity) { 10 }
  let(:item_name) { 'Sample Item' }

  it 'converts item to hash with stringified keys' do
    expected_hash = {'item_id' => '1', 'quantity' => '10', 'item_name' => 'Sample Item'}
    expect(inventory_item.to_h).to eq(expected_hash)
  end

  describe 'when item_id is nil' do
    let(:item_id) { nil }

    it 'handles nil item_id' do
      expected_hash = {'item_id' => nil, 'quantity' => '10', 'item_name' => 'Sample Item'}
      expect(inventory_item.to_h).to eq(expected_hash)
    end
  end

  describe 'when quantity is nil' do
    let(:quantity) { nil }

    it 'handles nil quantity' do
      expected_hash = {'item_id' => '1', 'quantity' => nil, 'item_name' => 'Sample Item'}
      expect(inventory_item.to_h).to eq(expected_hash)
    end
  end

  describe 'when item is nil' do
    let(:item) { nil }

    it 'handles nil item' do
      expected_hash = {'item_id' => '1', 'quantity' => '10', 'item_name' => nil}
      expect(inventory_item.to_h).to eq(expected_hash)
    end
  end

  describe 'when item.name is nil' do
    let(:item_name) { nil }

    it 'handles nil item name' do
      expected_hash = {'item_id' => '1', 'quantity' => '10', 'item_name' => nil}
      expect(inventory_item.to_h).to eq(expected_hash)
    end
  end
end
end
