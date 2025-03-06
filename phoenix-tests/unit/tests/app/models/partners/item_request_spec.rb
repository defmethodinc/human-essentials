
require "rails_helper"

RSpec.describe Partners::ItemRequest do
describe '#request_unit_is_supported', :phoenix do
  let(:item) { build(:item, :with_unit, unit: request_unit_name) }
  let(:item_request) { build(:item_request, item: item, request_unit: request_unit) }
  let(:request_unit_name) { "pack" }

  context 'when request_unit is blank' do
    let(:request_unit) { nil }

    it 'returns early if request_unit is blank' do
      item_request.request_unit_is_supported
      expect(item_request.errors[:request_unit]).to be_empty
    end
  end

  context 'when request_unit is included in item.request_units' do
    let(:request_unit) { request_unit_name }

    it 'does not add any errors' do
      item_request.request_unit_is_supported
      expect(item_request.errors[:request_unit]).to be_empty
    end
  end

  context 'when request_unit is not included in item.request_units' do
    let(:request_unit) { "unsupported_unit" }

    it 'adds an error to errors' do
      item_request.request_unit_is_supported
      expect(item_request.errors[:request_unit]).to include("is not supported")
    end
  end
end
describe '#name_with_unit', :phoenix do
  let(:item_request) { build(:item_request, item: item, request_unit: request_unit, quantity: quantity) }
  let(:item) { build(:item, name: 'Sample Item') }
  let(:request_unit) { nil }
  let(:quantity) { 5 }

  context 'when item is nil' do
    let(:item) { nil }

    it 'returns nil' do
      expect(item_request.name_with_unit).to be_nil
    end
  end

  context 'when item is present' do
    context 'when Flipper feature :enable_packs is enabled and request_unit is present' do
      before do
        allow(Flipper).to receive(:enabled?).with(:enable_packs).and_return(true)
      end

      let(:request_unit) { 'pack' }

      context 'with quantity_override provided' do
        let(:quantity_override) { 10 }

        it 'returns name with pluralized request unit based on quantity_override' do
          expect(item_request.name_with_unit(quantity_override)).to eq('Sample Item - packs')
        end
      end

      context 'without quantity_override provided' do
        it 'returns name with pluralized request unit based on quantity' do
          expect(item_request.name_with_unit).to eq('Sample Item - packs')
        end
      end
    end

    context 'when Flipper feature :enable_packs is not enabled or request_unit is not present' do
      before do
        allow(Flipper).to receive(:enabled?).with(:enable_packs).and_return(false)
      end

      it 'returns just the name' do
        expect(item_request.name_with_unit).to eq('Sample Item')
      end
    end
  end
end
end
