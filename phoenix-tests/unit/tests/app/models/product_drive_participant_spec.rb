
require "rails_helper"

RSpec.describe ProductDriveParticipant do
describe "#volume", :phoenix do
  let(:product_drive_participant) { ProductDriveParticipant.new }

  context "when there are no donations" do
    it "returns 0" do
      allow(product_drive_participant).to receive(:donations).and_return([])
      expect(product_drive_participant.volume).to eq(0)
    end
  end

  context "when donations have no line items" do
    let(:donations) { [Donation.new(line_items: [])] }

    it "returns 0" do
      allow(product_drive_participant).to receive(:donations).and_return(donations)
      expect(product_drive_participant.volume).to eq(0)
    end
  end

  context "when donations have line items" do
    let(:line_items) { [LineItem.new(total: 10), LineItem.new(total: 20)] }
    let(:donations) { [Donation.new(line_items: line_items)] }

    it "calculates the total volume from line items" do
      allow(product_drive_participant).to receive(:donations).and_return(donations)
      expect(product_drive_participant.volume).to eq(30)
    end
  end

  context "with mixed donations" do
    let(:line_items1) { [LineItem.new(total: 10)] }
    let(:line_items2) { [LineItem.new(total: 20), LineItem.new(total: 30)] }
    let(:donations) { [Donation.new(line_items: line_items1), Donation.new(line_items: line_items2)] }

    it "calculates the total volume correctly for mixed donations" do
      allow(product_drive_participant).to receive(:donations).and_return(donations)
      expect(product_drive_participant.volume).to eq(60)
    end
  end

  context "handles edge cases such as large numbers" do
    let(:line_items) { [LineItem.new(total: 1_000_000_000), LineItem.new(total: 2_000_000_000)] }
    let(:donations) { [Donation.new(line_items: line_items)] }

    it "calculates the total volume correctly for large numbers" do
      allow(product_drive_participant).to receive(:donations).and_return(donations)
      expect(product_drive_participant.volume).to eq(3_000_000_000)
    end
  end
end
describe "#volume_by_product_drive", :phoenix do
  let(:product_drive_participant) { create(:product_drive_participant) }
  let(:product_drive_id) { 1 }

  context "when there are no donations" do
    it "returns 0" do
      expect(product_drive_participant.volume_by_product_drive(product_drive_id)).to eq(0)
    end
  end

  context "when donations have no line items" do
    let!(:donation) { Donation.create(product_drive_id: product_drive_id, line_items: []) }

    it "returns 0" do
      expect(product_drive_participant.volume_by_product_drive(product_drive_id)).to eq(0)
    end
  end

  context "when donations have line items" do
    let!(:donation) { Donation.create(product_drive_id: product_drive_id) }
    let!(:line_item1) { LineItem.create(donation: donation, total: 5) }
    let!(:line_item2) { LineItem.create(donation: donation, total: 10) }

    it "calculates the total volume correctly" do
      expect(product_drive_participant.volume_by_product_drive(product_drive_id)).to eq(15)
    end
  end

  context "when product_drive_id is invalid" do
    let(:invalid_product_drive_id) { 999 }

    it "returns 0" do
      expect(product_drive_participant.volume_by_product_drive(invalid_product_drive_id)).to eq(0)
    end
  end
end
describe '#donation_source_view', :phoenix do
  let(:product_drive_participant_with_contact_name) { ProductDriveParticipant.new(contact_name: 'John Doe') }
  let(:product_drive_participant_without_contact_name) { ProductDriveParticipant.new(contact_name: '') }

  it 'returns nil when contact_name is blank' do
    participant = product_drive_participant_without_contact_name
    expect(participant.donation_source_view).to be_nil
  end

  it 'returns formatted string when contact_name is present' do
    participant = product_drive_participant_with_contact_name
    expect(participant.donation_source_view).to eq('John Doe (participant)')
  end
end
end
