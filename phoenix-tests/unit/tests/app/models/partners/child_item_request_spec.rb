
require "rails_helper"

RSpec.describe Partners::ChildItemRequest do
describe '#quantity', :phoenix do
  let(:item_request) { ItemRequest.create(quantity: item_request_quantity) }
  let(:children) { Array.new(children_count) { Child.create } }
  let(:child_item_request) { Partners::ChildItemRequest.new(item_request: item_request, children: children) }

  context 'when item_request quantity is zero' do
    let(:item_request_quantity) { 0 }
    let(:children_count) { 1 }

    it 'returns zero' do
      expect(child_item_request.quantity).to eq(0)
    end
  end

  context 'when there are no children' do
    let(:item_request_quantity) { 10 }
    let(:children_count) { 0 }

    it 'returns zero' do
      expect(child_item_request.quantity).to eq(0)
    end
  end

  context 'when there is one child' do
    let(:item_request_quantity) { 10 }
    let(:children_count) { 1 }

    it 'returns correct quantity equal to item_request quantity' do
      expect(child_item_request.quantity).to eq(10)
    end
  end

  context 'when there are multiple children' do
    let(:item_request_quantity) { 10 }
    let(:children_count) { 2 }

    it 'returns correct quantity divided by number of children' do
      expect(child_item_request.quantity).to eq(5)
    end
  end

  context 'when handling division by zero gracefully' do
    let(:item_request_quantity) { 10 }
    let(:children_count) { 0 }

    it 'returns zero when dividing by zero' do
      expect(child_item_request.quantity).to eq(0)
    end
  end
end
describe '#ordered_item_diaperid', :phoenix do
  let(:item_request) { ItemRequest.new(item_id: item_id) }
  let(:child_item_request) { Partners::ChildItemRequest.new(item_request: item_request) }

  context 'when item_request is present' do
    let(:item_id) { 1 }

    it 'returns the item_id when item_request is present' do
      expect(child_item_request.ordered_item_diaperid).to eq(item_id)
    end
  end

  context 'when item_request is nil' do
    let(:item_request) { nil }

    it 'does not raise an error when item_request is nil' do
      expect { child_item_request.ordered_item_diaperid }.not_to raise_error
    end
  end

  context 'when item_id is nil' do
    let(:item_id) { nil }

    it 'returns nil when item_id is nil' do
      expect(child_item_request.ordered_item_diaperid).to be_nil
    end
  end

  context 'when item_id is invalid' do
    let(:item_id) { 'invalid' }

    it 'returns the invalid item_id as is' do
      expect(child_item_request.ordered_item_diaperid).to eq('invalid')
    end
  end
end
end
