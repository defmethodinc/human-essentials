
require "rails_helper"

RSpec.describe Vendor do
describe '#volume', :phoenix do
  let(:vendor) { create(:vendor) }

  context 'when there are no purchases' do
    it 'returns 0' do
      expect(vendor.volume).to eq(0)
    end
  end

  context 'when purchases have no line items' do
    let!(:purchase) { create(:purchase, vendor: vendor, line_items: []) }

    it 'returns 0' do
      expect(vendor.volume).to eq(0)
    end
  end

  context 'when line items have zero total' do
    let!(:purchase) { create(:purchase, vendor: vendor) }
    let!(:line_item) { create(:line_item, quantity: 0, itemizable: purchase) }

    it 'returns 0' do
      expect(vendor.volume).to eq(0)
    end
  end

  context 'when line items have positive totals' do
    let!(:purchase) { create(:purchase, vendor: vendor) }
    let!(:line_item) { create(:line_item, quantity: 5, itemizable: purchase) }

    it 'returns the correct total' do
      expect(vendor.volume).to eq(5)
    end
  end

  context 'when line items have negative totals' do
    let!(:purchase) { create(:purchase, vendor: vendor) }
    let!(:line_item) { create(:line_item, quantity: -3, itemizable: purchase) }

    it 'returns the correct total' do
      expect(vendor.volume).to eq(-3)
    end
  end

  context 'when line items have mixed totals' do
    let!(:purchase) { create(:purchase, vendor: vendor) }
    let!(:line_item1) { create(:line_item, quantity: 5, itemizable: purchase) }
    let!(:line_item2) { create(:line_item, quantity: -3, itemizable: purchase) }

    it 'returns the correct total' do
      expect(vendor.volume).to eq(2)
    end
  end
end
end
