
require "rails_helper"

RSpec.describe ProductDriveParticipant do
describe "#volume", :phoenix do
  let(:product_drive_participant) { create(:product_drive_participant) }

  context "when there are no donations" do
    it "returns 0" do
      expect(product_drive_participant.volume).to eq(0)
    end
  end

  context "when there are donations with line items" do
    before do
      donation1 = create(:donation, product_drive_participant: product_drive_participant)
      donation2 = create(:donation, product_drive_participant: product_drive_participant)
      create(:line_item, donation: donation1, quantity: 5)
      create(:line_item, donation: donation1, quantity: 10)
      create(:line_item, donation: donation2, quantity: 3)
    end

    it "returns the sum of all line item quantities" do
      expect(product_drive_participant.volume).to eq(18)
    end
  end

  context "when donations have line items with varying quantities" do
    before do
      donation = create(:donation, product_drive_participant: product_drive_participant)
      create(:line_item, donation: donation, quantity: 0)
      create(:line_item, donation: donation, quantity: 7)
      create(:line_item, donation: donation, quantity: 2)
    end

    it "calculates the correct total volume" do
      expect(product_drive_participant.volume).to eq(9)
    end
  end
end
describe "#volume_by_product_drive", :phoenix do
  let(:product_drive_participant) { ProductDriveParticipant.create }
  let(:product_drive_id) { 1 }
  let(:donation_with_line_items) do
    donation = Donation.create(product_drive_id: product_drive_id)
    LineItem.create(donation: donation, total: 100)
    donation
  end
  let(:donation_without_line_items) { Donation.create(product_drive_id: product_drive_id) }
  let(:invalid_product_drive_id) { 999 }

  it "calculates total volume for a valid product drive with donations" do
    donation_with_line_items
    expect(product_drive_participant.volume_by_product_drive(product_drive_id)).to eq(100)
  end

  it "returns zero when there are no donations for the product drive" do
    expect(product_drive_participant.volume_by_product_drive(product_drive_id)).to eq(0)
  end

  it "handles invalid product drive ID gracefully" do
    expect(product_drive_participant.volume_by_product_drive(invalid_product_drive_id)).to eq(0)
  end

  it "returns zero when donations have no line items" do
    donation_without_line_items
    expect(product_drive_participant.volume_by_product_drive(product_drive_id)).to eq(0)
  end
end
describe "#donation_source_view", :phoenix do
  let(:product_drive_participant) { ProductDriveParticipant.new(contact_name: contact_name) }

  context "when contact_name is blank" do
    let(:contact_name) { "" }

    it "returns nil" do
      expect(product_drive_participant.donation_source_view).to be_nil
    end
  end

  context "when contact_name is present" do
    let(:contact_name) { "John Doe" }

    it "returns the contact name with '(participant)'" do
      expect(product_drive_participant.donation_source_view).to eq("John Doe (participant)")
    end
  end
end
end
