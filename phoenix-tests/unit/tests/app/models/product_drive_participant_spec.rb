require "rails_helper"

RSpec.describe ProductDriveParticipant, type: :model do
  describe "validations" do
    context "when phone is not provided" do
      it "requires an email" do
        participant = ProductDriveParticipant.new(phone: nil, email: nil)
        expect(participant.valid?).to be_falsey
        expect(participant.errors[:email]).to include("Must provide a phone or an e-mail")
      end
    end

    context "when email is not provided" do
      it "requires a phone" do
        participant = ProductDriveParticipant.new(phone: nil, email: nil)
        expect(participant.valid?).to be_falsey
        expect(participant.errors[:phone]).to include("Must provide a phone or an e-mail")
      end
    end

    context "when contact_name is not provided" do
      it "requires a business_name" do
        participant = ProductDriveParticipant.new(contact_name: nil, business_name: nil)
        expect(participant.valid?).to be_falsey
        expect(participant.errors[:business_name]).to include("Must provide a name or a business name")
      end
    end

    context "when business_name is not provided" do
      it "requires a contact_name" do
        participant = ProductDriveParticipant.new(contact_name: nil, business_name: nil)
        expect(participant.valid?).to be_falsey
        expect(participant.errors[:contact_name]).to include("Must provide a name or a business name")
      end
    end

    it "validates the length of comment" do
      participant = ProductDriveParticipant.new(comment: "a" * 501)
      expect(participant.valid?).to be_falsey
      expect(participant.errors[:comment]).to include("is too long (maximum is 500 characters)")
    end
  end

  describe "scopes" do
    describe ".alphabetized" do
      it "orders participants by contact_name" do
        organization = Organization.create!(name: "Test Org")
        participant1 = ProductDriveParticipant.create!(contact_name: "Zed", business_name: "Zed's Business", phone: "123456789", organization: organization)
        participant2 = ProductDriveParticipant.create!(contact_name: "Alice", business_name: "Alice's Business", phone: "987654321", organization: organization)
        expect(ProductDriveParticipant.alphabetized).to eq([participant2, participant1])
      end
    end
  end

  describe "#volume" do
    it "calculates the total volume of donations" do
      organization = Organization.create!(name: "Test Org")
      participant = ProductDriveParticipant.create!(contact_name: "John Doe", business_name: "John's Business", phone: "123456789", organization: organization)
      donation1 = participant.donations.create!(organization: organization)
      donation2 = participant.donations.create!(organization: organization)
      allow(donation1.line_items).to receive(:total).and_return(100)
      allow(donation2.line_items).to receive(:total).and_return(200)
      expect(participant.volume).to eq(300)
    end
  end

  describe "#volume_by_product_drive" do
    it "calculates the total volume of donations for a specific product drive" do
      organization = Organization.create!(name: "Test Org")
      participant = ProductDriveParticipant.create!(contact_name: "John Doe", business_name: "John's Business", phone: "123456789", organization: organization)
      donation1 = participant.donations.create!(product_drive_id: 1, organization: organization)
      donation2 = participant.donations.create!(product_drive_id: 2, organization: organization)
      allow(donation1.line_items).to receive(:total).and_return(100)
      allow(donation2.line_items).to receive(:total).and_return(200)
      allow(participant.donations).to receive(:by_product_drive).with(1).and_return([donation1])
      expect(participant.volume_by_product_drive(1)).to eq(100)
    end
  end

  describe "#donation_source_view" do
    context "when contact_name is present" do
      it "returns the contact name with participant label" do
        participant = ProductDriveParticipant.new(contact_name: "John Doe")
        expect(participant.donation_source_view).to eq("John Doe (participant)")
      end
    end

    context "when contact_name is blank" do
      it "returns nil" do
        participant = ProductDriveParticipant.new(contact_name: nil)
        expect(participant.donation_source_view).to be_nil
      end
    end
  end
end
