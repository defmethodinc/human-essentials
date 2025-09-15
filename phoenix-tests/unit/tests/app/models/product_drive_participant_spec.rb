
require "rails_helper"

RSpec.describe ProductDriveParticipant do
describe "#volume", :phoenix do
  let(:product_drive_participant) { ProductDriveParticipant.new(donations: donations) }

  context "when there are no donations" do
    let(:donations) { [] }

    it "returns 0 for empty donations" do
      expect(product_drive_participant.volume).to eq(0)
    end
  end

  context "when there is a single donation" do
    let(:donations) { [Donation.new(line_items: [LineItem.new(total: 10)])] }

    it "calculates total for a single donation" do
      expect(product_drive_participant.volume).to eq(10)
    end
  end

  context "when there are multiple donations" do
    let(:donations) { [Donation.new(line_items: [LineItem.new(total: 10)]), Donation.new(line_items: [LineItem.new(total: 20)])] }

    it "calculates total for multiple donations" do
      expect(product_drive_participant.volume).to eq(30)
    end
  end

  context "when donations have no line items" do
    let(:donations) { [Donation.new(line_items: [])] }

    it "handles donations with no line items" do
      expect(product_drive_participant.volume).to eq(0)
    end
  end

  context "when there are mixed donations" do
    let(:donations) { [Donation.new(line_items: [LineItem.new(total: 10)]), Donation.new(line_items: [])] }

    it "calculates total for mixed donations" do
      expect(product_drive_participant.volume).to eq(10)
    end
  end

  context "when donations are nil" do
    let(:donations) { nil }

    it "handles nil donations" do
      expect(product_drive_participant.volume).to eq(0)
    end
  end
end
describe '#volume_by_product_drive', :phoenix do
  let(:product_drive_participant) { create(:product_drive_participant) }
  let(:product_drive_id) { 1 }

  context 'when there are no donations for the given product drive' do
    it 'returns 0' do
      expect(product_drive_participant.volume_by_product_drive(product_drive_id)).to eq(0)
    end
  end

  context 'when there are donations with line items' do
    let!(:donation_with_line_items) do
      donation = Donation.create(product_drive_id: product_drive_id)
      LineItem.create(donation: donation, total: 10)
      LineItem.create(donation: donation, total: 20)
      donation
    end

    it 'calculates the total volume' do
      expect(product_drive_participant.volume_by_product_drive(product_drive_id)).to eq(30)
    end
  end

  context 'when there are donations but no line items' do
    let!(:donation_without_line_items) { Donation.create(product_drive_id: product_drive_id) }

    it 'returns 0' do
      expect(product_drive_participant.volume_by_product_drive(product_drive_id)).to eq(0)
    end
  end

  context 'when handling invalid product drive ID' do
    let(:invalid_product_drive_id) { -1 }

    it 'handles gracefully' do
      expect(product_drive_participant.volume_by_product_drive(invalid_product_drive_id)).to eq(0)
    end
  end
end
describe "#donation_source_view", :phoenix do
  let(:product_drive_participant_with_contact_name) { ProductDriveParticipant.new(contact_name: "John Doe") }
  let(:product_drive_participant_without_contact_name) { ProductDriveParticipant.new(contact_name: "") }

  it "returns nil when contact_name is blank" do
    participant = product_drive_participant_without_contact_name
    expect(participant.donation_source_view).to be_nil
  end

  it "returns contact_name with (participant) when contact_name is present" do
    participant = product_drive_participant_with_contact_name
    expect(participant.donation_source_view).to eq("John Doe (participant)")
  end
end
end
