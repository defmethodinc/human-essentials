
require "rails_helper"

RSpec.describe ProductDriveParticipant do
describe '#volume', :phoenix do
  let(:product_drive_participant) { ProductDriveParticipant.new }

  context 'when there are no donations' do
    it 'returns zero' do
      allow(product_drive_participant).to receive(:donations).and_return([])
      expect(product_drive_participant.volume).to eq(0)
    end
  end

  context 'when there are donations but no line items' do
    let(:donations) { [Donation.new(line_items: [])] }

    it 'returns zero' do
      allow(product_drive_participant).to receive(:donations).and_return(donations)
      expect(product_drive_participant.volume).to eq(0)
    end
  end

  context 'when line items have zero total' do
    let(:line_items) { [LineItem.new(total: 0)] }
    let(:donations) { [Donation.new(line_items: line_items)] }

    it 'returns zero' do
      allow(product_drive_participant).to receive(:donations).and_return(donations)
      expect(product_drive_participant.volume).to eq(0)
    end
  end

  context 'when line items have positive totals' do
    let(:line_items) { [LineItem.new(total: 10)] }
    let(:donations) { [Donation.new(line_items: line_items)] }

    it 'returns the sum of line item totals' do
      allow(product_drive_participant).to receive(:donations).and_return(donations)
      expect(product_drive_participant.volume).to eq(10)
    end
  end

  context 'when line items have negative totals' do
    let(:line_items) { [LineItem.new(total: -5)] }
    let(:donations) { [Donation.new(line_items: line_items)] }

    it 'returns the sum of line item totals' do
      allow(product_drive_participant).to receive(:donations).and_return(donations)
      expect(product_drive_participant.volume).to eq(-5)
    end
  end

  context 'for multiple donations with mixed line item totals' do
    let(:line_items1) { [LineItem.new(total: 10), LineItem.new(total: -5)] }
    let(:line_items2) { [LineItem.new(total: 20)] }
    let(:donations) { [Donation.new(line_items: line_items1), Donation.new(line_items: line_items2)] }

    it 'returns the sum of all line item totals' do
      allow(product_drive_participant).to receive(:donations).and_return(donations)
      expect(product_drive_participant.volume).to eq(25)
    end
  end
end
describe "#volume_by_product_drive", :phoenix do
  let(:product_drive_id) { 1 }
  let(:donation_with_line_items) do
    donation = Donation.create(product_drive_id: product_drive_id)
    LineItem.create(donation: donation, total: 10)
    LineItem.create(donation: donation, total: 20)
    donation
  end
  let(:donation_without_line_items) { Donation.create(product_drive_id: product_drive_id) }
  let(:invalid_product_drive_id) { 999 }

  it "calculates the total volume for a given product drive ID" do
    donation_with_line_items
    expect(subject.volume_by_product_drive(product_drive_id)).to eq(30)
  end

  it "returns zero when there are no donations for the given product drive ID" do
    expect(subject.volume_by_product_drive(invalid_product_drive_id)).to eq(0)
  end

  it "calculates the total volume correctly when there are multiple donations" do
    donation1 = Donation.create(product_drive_id: product_drive_id)
    LineItem.create(donation: donation1, total: 15)
    donation_with_line_items
    expect(subject.volume_by_product_drive(product_drive_id)).to eq(45)
  end

  describe "edge cases" do
    it "handles invalid product drive ID" do
      expect(subject.volume_by_product_drive(invalid_product_drive_id)).to eq(0)
    end

    it "handles donations with no line items" do
      donation_without_line_items
      expect(subject.volume_by_product_drive(product_drive_id)).to eq(0)
    end
  end
end
describe "#donation_source_view", :phoenix do
  let(:product_drive_participant_with_contact_name) { ProductDriveParticipant.new(contact_name: "John Doe") }
  let(:product_drive_participant_without_contact_name) { ProductDriveParticipant.new(contact_name: nil) }

  it "returns nil when contact_name is blank" do
    participant = product_drive_participant_without_contact_name
    expect(participant.donation_source_view).to be_nil
  end

  it "returns formatted string with contact_name when contact_name is present" do
    participant = product_drive_participant_with_contact_name
    expect(participant.donation_source_view).to eq("John Doe (participant)")
  end
end
end
