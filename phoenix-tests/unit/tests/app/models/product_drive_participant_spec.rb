require "rails_helper"

RSpec.describe ProductDriveParticipant, type: :model do
  let(:organization) { Organization.create!(name: "Test Org") }
  let(:product_drive_participant) { described_class.new(organization: organization) }

  describe "associations" do
    it "has many donations" do
      association = described_class.reflect_on_association(:donations)
      expect(association.macro).to eq(:has_many)
      expect(association.options[:inverse_of]).to eq(:product_drive_participant)
      expect(association.options[:dependent]).to eq(:destroy)
    end
  end

  describe "validations" do
    context "when phone is blank" do
      it "validates presence of email" do
        product_drive_participant.phone = nil
        product_drive_participant.email = nil
        product_drive_participant.valid?
        expect(product_drive_participant.errors[:email]).to include("Must provide a phone or an e-mail")
      end
    end

    context "when email is blank" do
      it "validates presence of phone" do
        product_drive_participant.email = nil
        product_drive_participant.phone = nil
        product_drive_participant.valid?
        expect(product_drive_participant.errors[:phone]).to include("Must provide a phone or an e-mail")
      end
    end

    context "when contact_name is blank" do
      it "validates presence of business_name" do
        product_drive_participant.contact_name = nil
        product_drive_participant.business_name = nil
        product_drive_participant.valid?
        expect(product_drive_participant.errors[:business_name]).to include("Must provide a name or a business name")
      end
    end

    context "when business_name is blank" do
      it "validates presence of contact_name" do
        product_drive_participant.business_name = nil
        product_drive_participant.contact_name = nil
        product_drive_participant.valid?
        expect(product_drive_participant.errors[:contact_name]).to include("Must provide a name or a business name")
      end
    end

    it "validates length of comment" do
      product_drive_participant.comment = "a" * 501
      product_drive_participant.valid?
      expect(product_drive_participant.errors[:comment]).to include("is too long (maximum is 500 characters)")
    end
  end

  describe "scopes" do
    describe ".alphabetized" do
      it "orders by contact_name" do
        participant1 = ProductDriveParticipant.create!(contact_name: "Zeta", email: "zeta@example.com", organization: organization)
        participant2 = ProductDriveParticipant.create!(contact_name: "Alpha", email: "alpha@example.com", organization: organization)
        expect(ProductDriveParticipant.alphabetized).to eq([participant2, participant1])
      end
    end
  end

  describe "#volume" do
    it "calculates total volume of donations" do
      donation1 = double("Donation", line_items: double("LineItems", total: 10))
      donation2 = double("Donation", line_items: double("LineItems", total: 20))
      allow(product_drive_participant).to receive(:donations).and_return([donation1, donation2])
      expect(product_drive_participant.volume).to eq(30)
    end
  end

  describe "#volume_by_product_drive" do
    it "calculates total volume of donations for a specific product drive" do
      product_drive_id = 1
      donation1 = double("Donation", line_items: double("LineItems", total: 10))
      donation2 = double("Donation", line_items: double("LineItems", total: 20))
      allow(product_drive_participant).to receive_message_chain(:donations, :by_product_drive).with(product_drive_id).and_return([donation1, donation2])
      expect(product_drive_participant.volume_by_product_drive(product_drive_id)).to eq(30)
    end
  end

  describe "#donation_source_view" do
    context "when contact_name is present" do
      it "returns the contact name with participant label" do
        product_drive_participant.contact_name = "John Doe"
        expect(product_drive_participant.donation_source_view).to eq("John Doe (participant)")
      end
    end

    context "when contact_name is blank" do
      it "returns nil" do
        product_drive_participant.contact_name = nil
        expect(product_drive_participant.donation_source_view).to be_nil
      end
    end
  end
end
