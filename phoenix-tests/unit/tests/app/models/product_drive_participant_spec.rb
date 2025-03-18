
require "rails_helper"

RSpec.describe ProductDriveParticipant do
describe '#volume' do
  let(:product_drive_participant) { create(:product_drive_participant) }
  let(:donation_with_no_line_items) { build(:donation, line_items: [], product_drive_participant: product_drive_participant) }
  let(:donation_with_zero_total_line_items) { build(:donation, line_items: [build(:line_item, quantity: 0)], product_drive_participant: product_drive_participant) }
  let(:donation_with_positive_totals) { build(:donation, line_items: [build(:line_item, quantity: 5)], product_drive_participant: product_drive_participant) }
  let(:donation_with_negative_totals) { build(:donation, line_items: [build(:line_item, quantity: -5)], product_drive_participant: product_drive_participant) }
  let(:donation_with_mixed_totals) { build(:donation, line_items: [build(:line_item, quantity: 5), build(:line_item, quantity: -5), build(:line_item, quantity: 0)], product_drive_participant: product_drive_participant) }

  it 'returns zero when there are no donations' do
    allow(product_drive_participant).to receive(:donations).and_return([])
    expect(product_drive_participant.volume).to eq(0)
  end

  it 'returns zero when donations have no line items' do
    allow(product_drive_participant).to receive(:donations).and_return([donation_with_no_line_items])
    expect(product_drive_participant.volume).to eq(0)
  end

  it 'returns zero when all line items have zero total' do
    allow(product_drive_participant).to receive(:donations).and_return([donation_with_zero_total_line_items])
    expect(product_drive_participant.volume).to eq(0)
  end

  it 'sums up positive totals correctly' do
    allow(product_drive_participant).to receive(:donations).and_return([donation_with_positive_totals])
    expect(product_drive_participant.volume).to eq(5)
  end

  it 'sums up negative totals correctly' do
    allow(product_drive_participant).to receive(:donations).and_return([donation_with_negative_totals])
    expect(product_drive_participant.volume).to eq(-5)
  end

  it 'handles a mix of positive, negative, and zero totals correctly' do
    allow(product_drive_participant).to receive(:donations).and_return([donation_with_mixed_totals])
    expect(product_drive_participant.volume).to eq(0)
  end
end
describe '#donation_source_view', :phoenix do
  let(:product_drive_participant) { build(:product_drive_participant, contact_name: contact_name) }

  context 'when contact_name is blank' do
    let(:contact_name) { '' }

    it 'returns nil' do
      expect(product_drive_participant.donation_source_view).to be_nil
    end
  end

  context 'when contact_name is present' do
    let(:contact_name) { 'Don Draper' }

    it 'returns the contact name with (participant)' do
      expect(product_drive_participant.donation_source_view).to eq('Don Draper (participant)')
    end
  end
end
describe '#volume' do
  let(:product_drive_participant) { create(:product_drive_participant) }
  let(:donation_with_no_line_items) { build(:donation, line_items: [], product_drive_participant: product_drive_participant) }
  let(:donation_with_zero_total_line_items) { build(:donation, line_items: [build(:line_item, quantity: 0)], product_drive_participant: product_drive_participant) }
  let(:donation_with_positive_totals) { build(:donation, line_items: [build(:line_item, quantity: 5)], product_drive_participant: product_drive_participant) }
  let(:donation_with_negative_totals) { build(:donation, line_items: [build(:line_item, quantity: -5)], product_drive_participant: product_drive_participant) }
  let(:donation_with_mixed_totals) { build(:donation, line_items: [build(:line_item, quantity: 5), build(:line_item, quantity: -5), build(:line_item, quantity: 0)], product_drive_participant: product_drive_participant) }

  it 'returns zero when there are no donations' do
    allow(product_drive_participant).to receive(:donations).and_return([])
    expect(product_drive_participant.volume).to eq(0)
  end

  it 'returns zero when donations have no line items' do
    allow(product_drive_participant).to receive(:donations).and_return([donation_with_no_line_items])
    expect(product_drive_participant.volume).to eq(0)
  end

  it 'returns zero when all line items have zero total' do
    allow(product_drive_participant).to receive(:donations).and_return([donation_with_zero_total_line_items])
    expect(product_drive_participant.volume).to eq(0)
  end

  it 'sums up positive totals correctly' do
    allow(product_drive_participant).to receive(:donations).and_return([donation_with_positive_totals])
    expect(product_drive_participant.volume).to eq(5)
  end

  it 'sums up negative totals correctly' do
    allow(product_drive_participant).to receive(:donations).and_return([donation_with_negative_totals])
    expect(product_drive_participant.volume).to eq(-5)
  end

  it 'handles a mix of positive, negative, and zero totals correctly' do
    allow(product_drive_participant).to receive(:donations).and_return([donation_with_mixed_totals])
    expect(product_drive_participant.volume).to eq(0)
  end
end
describe '#volume_by_product_drive', :phoenix do
  let(:product_drive) { create(:product_drive) }
  let(:product_drive_participant) { create(:product_drive_participant) }

  context 'when there are no donations' do
    it 'returns 0' do
      expect(product_drive_participant.volume_by_product_drive(product_drive.id)).to eq(0)
    end
  end

  context 'when donations have no line items' do
    let!(:donation) { create(:product_drive_donation, product_drive: product_drive, product_drive_participant: product_drive_participant) }

    it 'returns 0' do
      expect(product_drive_participant.volume_by_product_drive(product_drive.id)).to eq(0)
    end
  end

  context 'when donations have line items' do
    let!(:donation) { create(:product_drive_donation, :with_items, product_drive: product_drive, product_drive_participant: product_drive_participant, item_quantity: 5) }

    it 'calculates the total volume correctly for donations with line items' do
      expect(product_drive_participant.volume_by_product_drive(product_drive.id)).to eq(5)
    end
  end

  describe 'when there are multiple product drives' do
    let(:another_product_drive) { create(:product_drive) }
    let!(:donation_for_another_drive) { create(:product_drive_donation, :with_items, product_drive: another_product_drive, product_drive_participant: product_drive_participant, item_quantity: 3) }
    let!(:donation_for_specified_drive) { create(:product_drive_donation, :with_items, product_drive: product_drive, product_drive_participant: product_drive_participant, item_quantity: 2) }

    it 'only sums line items for the specified product drive' do
      expect(product_drive_participant.volume_by_product_drive(product_drive.id)).to eq(2)
    end
  end
end
end
