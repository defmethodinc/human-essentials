
require "rails_helper"

RSpec.describe ProductDriveParticipant do
describe "#volume", :phoenix do
  let(:product_drive_participant) { ProductDriveParticipant.new }
  let(:donation) { Donation.new }
  let(:line_item) { LineItem.new }

  it "returns 0 for empty donations" do
    allow(product_drive_participant).to receive(:donations).and_return([])
    expect(product_drive_participant.volume).to eq(0)
  end

  describe "with a single donation" do
    before do
      allow(donation).to receive(:line_items).and_return([line_item])
      allow(line_item).to receive(:total).and_return(100)
    end

    it "calculates total for a single donation" do
      allow(product_drive_participant).to receive(:donations).and_return([donation])
      expect(product_drive_participant.volume).to eq(100)
    end
  end

  describe "with multiple donations" do
    before do
      allow(donation).to receive(:line_items).and_return([line_item, line_item])
      allow(line_item).to receive(:total).and_return(50)
    end

    it "calculates total for multiple donations" do
      allow(product_drive_participant).to receive(:donations).and_return([donation, donation])
      expect(product_drive_participant.volume).to eq(200)
    end
  end

  describe "with nil or invalid line items" do
    before do
      allow(donation).to receive(:line_items).and_return([nil, line_item])
      allow(line_item).to receive(:total).and_return(50)
    end

    it "handles nil or invalid line items gracefully" do
      allow(product_drive_participant).to receive(:donations).and_return([donation])
      expect(product_drive_participant.volume).to eq(50)
    end
  end

  describe "with edge cases like large numbers or negative totals" do
    before do
      allow(donation).to receive(:line_items).and_return([line_item])
      allow(line_item).to receive(:total).and_return(-100)
    end

    it "handles negative totals" do
      allow(product_drive_participant).to receive(:donations).and_return([donation])
      expect(product_drive_participant.volume).to eq(-100)
    end
  end
end
describe "#volume_by_product_drive", :phoenix do
  let(:product_drive_participant) { ProductDriveParticipant.create }
  let(:product_drive_id) { 1 }
  let(:donation_with_line_items) do
    donation = Donation.create(product_drive_id: product_drive_id)
    donation.line_items.create(total: 100)
    donation
  end
  let(:donation_without_line_items) { Donation.create(product_drive_id: product_drive_id) }
  let(:donation_with_zero_total_line_items) do
    donation = Donation.create(product_drive_id: product_drive_id)
    donation.line_items.create(total: 0)
    donation
  end

  it "calculates total volume for a given product drive" do
    donation_with_line_items
    expect(product_drive_participant.volume_by_product_drive(product_drive_id)).to eq(100)
  end

  it "returns zero when there are no donations for the given product drive" do
    expect(product_drive_participant.volume_by_product_drive(product_drive_id)).to eq(0)
  end

  it "handles invalid product drive ID gracefully" do
    expect(product_drive_participant.volume_by_product_drive(-1)).to eq(0)
  end

  describe "edge cases" do
    it "returns zero when donations have no line items" do
      donation_without_line_items
      expect(product_drive_participant.volume_by_product_drive(product_drive_id)).to eq(0)
    end

    it "returns zero when line items total zero" do
      donation_with_zero_total_line_items
      expect(product_drive_participant.volume_by_product_drive(product_drive_id)).to eq(0)
    end
  end
end
describe '#donation_source_view', :phoenix do
  let(:product_drive_participant_with_contact_name) { ProductDriveParticipant.new(contact_name: 'John Doe') }
  let(:product_drive_participant_without_contact_name) { ProductDriveParticipant.new(contact_name: nil) }

  it 'returns nil when contact_name is blank' do
    participant = product_drive_participant_without_contact_name
    expect(participant.donation_source_view).to be_nil
  end

  it 'returns contact_name with participant label when contact_name is present' do
    participant = product_drive_participant_with_contact_name
    expect(participant.donation_source_view).to eq('John Doe (participant)')
  end
end
end
