
require "rails_helper"

RSpec.describe ProductDriveParticipant do
describe "#volume", :phoenix do
  let(:product_drive_participant) { create(:product_drive_participant, donations: donations) }
  let(:donations) { [] }

  it "returns 0 for empty donations" do
    expect(product_drive_participant.volume).to eq(0)
  end

  context "when donations have no line items" do
    let(:donations) { [create(:donation, line_items: [])] }

    it "returns 0 for donations with no line items" do
      expect(product_drive_participant.volume).to eq(0)
    end
  end

  context "when donations have line items" do
    let(:line_item1) { create(:line_item, total: 10) }
    let(:line_item2) { create(:line_item, total: 20) }
    let(:donations) { [create(:donation, line_items: [line_item1, line_item2])] }

    it "calculates total for donations with line items" do
      expect(product_drive_participant.volume).to eq(30)
    end
  end

  context "when donations are mixed" do
    let(:line_item1) { create(:line_item, total: 10) }
    let(:donations) { [create(:donation, line_items: [line_item1]), create(:donation, line_items: [])] }

    it "calculates total for mixed donations" do
      expect(product_drive_participant.volume).to eq(10)
    end
  end

  context "when donations have nil values" do
    let(:donations) { [nil, create(:donation, line_items: [])] }

    it "handles nil values gracefully" do
      expect(product_drive_participant.volume).to eq(0)
    end
  end
end
describe "#volume_by_product_drive", :phoenix do
  let(:product_drive_id) { 1 }
  let(:participant) { ProductDriveParticipant.new }

  it "returns 0 when there are no donations" do
    expect(participant.volume_by_product_drive(product_drive_id)).to eq(0)
  end

  it "calculates total volume for a single donation" do
    donation = Donation.create(product_drive_id: product_drive_id)
    LineItem.create(donation: donation, total: 10)
    expect(participant.volume_by_product_drive(product_drive_id)).to eq(10)
  end

  it "calculates total volume for multiple donations" do
    donation1 = Donation.create(product_drive_id: product_drive_id)
    LineItem.create(donation: donation1, total: 10)
    donation2 = Donation.create(product_drive_id: product_drive_id)
    LineItem.create(donation: donation2, total: 20)
    expect(participant.volume_by_product_drive(product_drive_id)).to eq(30)
  end

  it "handles donations with varying line item totals" do
    donation1 = Donation.create(product_drive_id: product_drive_id)
    LineItem.create(donation: donation1, total: 5)
    donation2 = Donation.create(product_drive_id: product_drive_id)
    LineItem.create(donation: donation2, total: 15)
    expect(participant.volume_by_product_drive(product_drive_id)).to eq(20)
  end

  it "returns 0 when product drive ID does not match any donation" do
    non_matching_product_drive_id = 2
    donation = Donation.create(product_drive_id: non_matching_product_drive_id)
    LineItem.create(donation: donation, total: 10)
    expect(participant.volume_by_product_drive(product_drive_id)).to eq(0)
  end
end
describe "#donation_source_view", :phoenix do
  let(:product_drive_participant_with_contact) { ProductDriveParticipant.new(contact_name: "John Doe") }
  let(:product_drive_participant_without_contact) { ProductDriveParticipant.new(contact_name: "") }

  it "returns nil when contact_name is blank" do
    participant = product_drive_participant_without_contact
    expect(participant.donation_source_view).to be_nil
  end

  it "returns contact_name with (participant) when contact_name is present" do
    participant = product_drive_participant_with_contact
    expect(participant.donation_source_view).to eq("John Doe (participant)")
  end
end
end
