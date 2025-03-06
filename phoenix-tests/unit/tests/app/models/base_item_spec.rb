
require "rails_helper"

RSpec.describe BaseItem do
describe '#to_h', :phoenix do
  let(:base_item) { build(:base_item, partner_key: partner_key, name: name) }
  let(:partner_key) { 'default_partner_key' }
  let(:name) { 'default_name' }

  it 'returns a hash with partner_key and name when both are present' do
    expect(base_item.to_h).to eq({ partner_key: 'default_partner_key', name: 'default_name' })
  end

  context 'when partner_key is nil' do
    let(:partner_key) { nil }

    it 'returns a hash with nil partner_key' do
      expect(base_item.to_h).to eq({ partner_key: nil, name: 'default_name' })
    end
  end

  context 'when name is nil' do
    let(:name) { nil }

    it 'returns a hash with nil name' do
      expect(base_item.to_h).to eq({ partner_key: 'default_partner_key', name: nil })
    end
  end

  context 'when both partner_key and name are nil' do
    let(:partner_key) { nil }
    let(:name) { nil }

    it 'returns a hash with both values nil' do
      expect(base_item.to_h).to eq({ partner_key: nil, name: nil })
    end
  end
end
end
