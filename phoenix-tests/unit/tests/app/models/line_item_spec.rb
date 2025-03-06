
require "rails_helper"

RSpec.describe LineItem do
describe '#quantity_must_be_a_number_within_range', :phoenix do
  let(:line_item) { build(:line_item, quantity: quantity) }

  context 'when quantity is greater than MAX_INT' do
    let(:quantity) { 2**31 + 1 }

    it 'adds an error for quantity being too large' do
      line_item.valid?
      expect(line_item.errors[:quantity]).to include("must be less than #{2**31}")
    end
  end

  context 'when quantity is less than MIN_INT' do
    let(:quantity) { -2**31 - 1 }

    it 'adds an error for quantity being too small' do
      line_item.valid?
      expect(line_item.errors[:quantity]).to include("must be greater than #{-2**31}")
    end
  end

  context 'when quantity is within the valid range' do
    let(:quantity) { 0 }

    it 'does not add any error' do
      line_item.valid?
      expect(line_item.errors[:quantity]).to be_empty
    end
  end

  context 'when quantity is nil' do
    let(:quantity) { nil }

    it 'does not add any error' do
      line_item.valid?
      expect(line_item.errors[:quantity]).to be_empty
    end
  end
end
end
