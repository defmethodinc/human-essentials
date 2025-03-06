
require "rails_helper"

RSpec.describe Errors::InsufficientAllotment do
describe '#initialize', :phoenix do
  let(:message) { 'Test message' }
  let(:insufficient_items) { [] }

  it 'sets @insufficient_items to an empty array when only a message is provided' do
    error = Errors::InsufficientAllotment.new(message)
    expect(error.instance_variable_get(:@insufficient_items)).to eq([])
  end

  it 'sets @insufficient_items to an empty array when an empty array is provided' do
    error = Errors::InsufficientAllotment.new(message, insufficient_items)
    expect(error.instance_variable_get(:@insufficient_items)).to eq([])
  end

  describe 'when initialized with a non-empty array' do
    let(:insufficient_items) { ['item1', 'item2'] }

    it 'sets @insufficient_items to the provided non-empty array' do
      error = Errors::InsufficientAllotment.new(message, insufficient_items)
      expect(error.instance_variable_get(:@insufficient_items)).to eq(['item1', 'item2'])
    end
  end
end
describe '#add_insufficiency', :phoenix do
  let(:item) { build(:item, id: 1, name: 'Test Item') }
  let(:quantity_on_hand) { 10 }
  let(:quantity_requested) { 5 }
  let(:insufficient_allotment) { Errors::InsufficientAllotment.new }

  it 'adds an item with correct attributes to insufficient_items' do
    insufficient_allotment.add_insufficiency(item, quantity_on_hand, quantity_requested)
    expect(insufficient_allotment.insufficient_items).to include(
      item_id: item.id,
      item: item.name,
      quantity_on_hand: quantity_on_hand,
      quantity_requested: quantity_requested
    )
  end

  describe 'when quantity_on_hand and quantity_requested are strings' do
    let(:quantity_on_hand) { '10' }
    let(:quantity_requested) { '5' }

    it 'converts quantity_on_hand to integer' do
      insufficient_allotment.add_insufficiency(item, quantity_on_hand, quantity_requested)
      expect(insufficient_allotment.insufficient_items.last[:quantity_on_hand]).to eq(10)
    end

    it 'converts quantity_requested to integer' do
      insufficient_allotment.add_insufficiency(item, quantity_on_hand, quantity_requested)
      expect(insufficient_allotment.insufficient_items.last[:quantity_requested]).to eq(5)
    end
  end

  describe 'when quantity_on_hand is zero' do
    let(:quantity_on_hand) { 0 }

    it 'handles zero quantity on hand' do
      insufficient_allotment.add_insufficiency(item, quantity_on_hand, quantity_requested)
      expect(insufficient_allotment.insufficient_items.last[:quantity_on_hand]).to eq(0)
    end
  end

  describe 'when quantity_requested is zero' do
    let(:quantity_requested) { 0 }

    it 'handles zero quantity requested' do
      insufficient_allotment.add_insufficiency(item, quantity_on_hand, quantity_requested)
      expect(insufficient_allotment.insufficient_items.last[:quantity_requested]).to eq(0)
    end
  end

  describe 'when quantity_on_hand is negative' do
    let(:quantity_on_hand) { -5 }

    it 'handles negative quantity on hand' do
      insufficient_allotment.add_insufficiency(item, quantity_on_hand, quantity_requested)
      expect(insufficient_allotment.insufficient_items.last[:quantity_on_hand]).to eq(-5)
    end
  end

  describe 'when quantity_requested is negative' do
    let(:quantity_requested) { -5 }

    it 'handles negative quantity requested' do
      insufficient_allotment.add_insufficiency(item, quantity_on_hand, quantity_requested)
      expect(insufficient_allotment.insufficient_items.last[:quantity_requested]).to eq(-5)
    end
  end

  it 'extracts item_id correctly from item object' do
    insufficient_allotment.add_insufficiency(item, quantity_on_hand, quantity_requested)
    expect(insufficient_allotment.insufficient_items.last[:item_id]).to eq(item.id)
  end

  it 'extracts item name correctly from item object' do
    insufficient_allotment.add_insufficiency(item, quantity_on_hand, quantity_requested)
    expect(insufficient_allotment.insufficient_items.last[:item]).to eq(item.name)
  end
end
describe '#satisfied?', :phoenix do
  let(:insufficient_items) { [] }
  let(:insufficient_allotment) { Errors::InsufficientAllotment.new(insufficient_items: insufficient_items) }

  it 'returns true when there are no insufficient items' do
    expect(insufficient_allotment.satisfied?).to be true
  end

  context 'when there are insufficient items' do
    let(:insufficient_items) { [build(:item)] }

    it 'returns false when there are insufficient items' do
      expect(insufficient_allotment.satisfied?).to be false
    end
  end
end
describe '#message', :phoenix do
  let(:insufficient_items) { [] }
  let(:insufficient_allotment) { Errors::InsufficientAllotment.new(insufficient_items: insufficient_items) }

  it 'returns base message when insufficient_items is empty' do
    expect(insufficient_allotment.message).to eq('Base message')
  end

  describe 'when insufficient_items contains one item' do
    context 'with quantity_requested greater than quantity_on_hand' do
      let(:insufficient_items) do
        [
          { quantity_requested: 5, item_name: 'Widget', quantity_on_hand: 3 }
        ]
      end

      it 'returns message for the item with excess request' do
        expect(insufficient_allotment.message).to eq('Base message 5 Widget requested, only 3 available. (Reduce by 2)')
      end
    end

    context 'with quantity_requested equal to quantity_on_hand' do
      let(:insufficient_items) do
        [
          { quantity_requested: 3, item_name: 'Widget', quantity_on_hand: 3 }
        ]
      end

      it 'returns message for the item with exact request' do
        expect(insufficient_allotment.message).to eq('Base message 3 Widget requested, only 3 available. (Reduce by 0)')
      end
    end
  end

  describe 'when insufficient_items contains multiple items' do
    let(:insufficient_items) do
      [
        { quantity_requested: 5, item_name: 'Widget', quantity_on_hand: 3 },
        { quantity_requested: 10, item_name: 'Gadget', quantity_on_hand: 8 }
      ]
    end

    it 'returns message for first item with excess request' do
      expect(insufficient_allotment.message).to include('5 Widget requested, only 3 available. (Reduce by 2)')
    end

    it 'returns message for second item with excess request' do
      expect(insufficient_allotment.message).to include('10 Gadget requested, only 8 available. (Reduce by 2)')
    end
  end
end
describe '#message', :phoenix do
  let(:insufficient_allotment_error) { Errors::InsufficientAllotment.new }

  it 'returns the correct error message' do
    expect(insufficient_allotment_error.message).to eq("Storage location kit doesn't match")
  end
end
describe '#message', :phoenix do
  it 'returns the correct error message for missing kit allocation' do
    expect(Errors::InsufficientAllotment.new.message).to eq('KitAllocation not found for given kit')
  end
end
describe '#message', :phoenix do
  it 'returns the correct message when inventory has items stored' do
    expect(subject.message).to eq('Could not complete action: inventory already has items stored')
  end
end
end
