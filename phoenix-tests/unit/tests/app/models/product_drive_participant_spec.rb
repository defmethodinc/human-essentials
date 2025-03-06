
require "rails_helper"

RSpec.describe ProductDriveParticipant do
describe "#volume", :phoenix do
  let(:product_drive_participant) { create(:product_drive_participant) }

  context "when there are no donations" do
    it "returns zero" do
      expect(product_drive_participant.volume).to eq(0)
    end
  end

  context "when donations have no line items" do
    let!(:donations) { create_list(:donation, 3, product_drive_participant: product_drive_participant) }

    it "returns zero" do
      expect(product_drive_participant.volume).to eq(0)
    end
  end

  context "when line items have zero total" do
    let!(:donations) { create_list(:donation, 3, :with_items, item_quantity: 0, product_drive_participant: product_drive_participant) }

    it "returns zero" do
      expect(product_drive_participant.volume).to eq(0)
    end
  end

  context "when line items have positive totals" do
    let!(:donations) { create_list(:donation, 3, :with_items, item_quantity: 10, product_drive_participant: product_drive_participant) }

    it "calculates the total volume correctly" do
      expect(product_drive_participant.volume).to eq(30)
    end
  end

  context "when line items have negative totals" do
    let!(:donations) { create_list(:donation, 3, :with_items, item_quantity: -5, product_drive_participant: product_drive_participant) }

    it "calculates the total volume correctly with negative totals" do
      expect(product_drive_participant.volume).to eq(-15)
    end
  end

  context "for multiple donations with various line item totals" do
    let!(:donation1) { create(:donation, :with_items, item_quantity: 10, product_drive_participant: product_drive_participant) }
    let!(:donation2) { create(:donation, :with_items, item_quantity: -5, product_drive_participant: product_drive_participant) }
    let!(:donation3) { create(:donation, :with_items, item_quantity: 0, product_drive_participant: product_drive_participant) }

    it "calculates the total volume correctly for mixed totals" do
      expect(product_drive_participant.volume).to eq(5)
    end
  end
end
describe "#volume_by_product_drive", :phoenix do
  let(:product_drive) { create(:product_drive) }
  let(:product_drive_participant) { create(:product_drive_participant) }

  context "when there are no donations for the given product_drive_id" do
    it "returns 0" do
      expect(product_drive_participant.volume_by_product_drive(product_drive.id)).to eq(0)
    end
  end

  context "when there are donations with the given product_drive_id" do
    let!(:donation_with_items) { create(:product_drive_donation, :with_items, product_drive: product_drive, product_drive_participant: product_drive_participant) }
    let!(:another_donation_with_items) { create(:product_drive_donation, :with_items, product_drive: product_drive, product_drive_participant: product_drive_participant) }

    it "calculates the total volume of line items for the product drive" do
      total_quantity = donation_with_items.line_items.pluck(:quantity).sum + another_donation_with_items.line_items.pluck(:quantity).sum
      expect(product_drive_participant.volume_by_product_drive(product_drive.id)).to eq(total_quantity)
    end
  end

  context "when the product_drive_id is invalid or does not exist" do
    it "returns 0" do
      expect(product_drive_participant.volume_by_product_drive(-1)).to eq(0)
    end
  end
end
describe "#donation_source_view", :phoenix do
  let(:product_drive_participant) { build(:product_drive_participant, contact_name: contact_name) }

  context "when contact_name is blank" do
    let(:contact_name) { "" }

    it "returns nil" do
      expect(product_drive_participant.donation_source_view).to be_nil
    end
  end

  context "when contact_name is present" do
    let(:contact_name) { "Don Draper" }

    it "returns the contact_name with (participant)" do
      expect(product_drive_participant.donation_source_view).to eq("Don Draper (participant)")
    end
  end
end
end
