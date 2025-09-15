require "rails_helper"

RSpec.describe ProductDriveParticipant, type: :model do
  describe "validations" do
    context "when phone is not present" do
      it "validates presence of email" do
        participant = ProductDriveParticipant.new(email: nil, phone: nil)
        expect(participant).not_to be_valid
        expect(participant.errors[:email]).to include("Must provide a phone or an e-mail")
      end
    end

    context "when email is not present" do
      it "validates presence of phone" do
        participant = ProductDriveParticipant.new(email: nil, phone: nil)
        expect(participant).not_to be_valid
        expect(participant.errors[:phone]).to include("Must provide a phone or an e-mail")
      end
    end

    context "when contact_name is not present" do
      it "validates presence of business_name" do
        participant = ProductDriveParticipant.new(contact_name: nil, business_name: nil)
        expect(participant).not_to be_valid
        expect(participant.errors[:business_name]).to include("Must provide a name or a business name")
      end
    end

    context "when business_name is not present" do
      it "validates presence of contact_name" do
        participant = ProductDriveParticipant.new(contact_name: nil, business_name: nil)
        expect(participant).not_to be_valid
        expect(participant.errors[:contact_name]).to include("Must provide a name or a business name")
      end
    end

    it "validates length of comment" do
      participant = ProductDriveParticipant.new(comment: "a" * 501)
      expect(participant).not_to be_valid
      expect(participant.errors[:comment]).to include("is too long (maximum is 500 characters)")
    end
  end

  describe "scopes" do
    describe ".alphabetized" do
      it "orders participants by contact_name" do
        organization = Organization.create!(name: "Test Org")
        participant1 = ProductDriveParticipant.create!(contact_name: "Zeta", phone: "1234567890", email: "zeta@example.com", organization: organization)
        participant2 = ProductDriveParticipant.create!(contact_name: "Alpha", phone: "0987654321", email: "alpha@example.com", organization: organization)
        expect(ProductDriveParticipant.alphabetized).to eq([participant2, participant1])
      end
    end
  end

  describe "#volume" do
    it "calculates the total volume of donations" do
      organization = Organization.create!(name: "Test Org")
      participant = ProductDriveParticipant.create!(contact_name: "John Doe", phone: "1234567890", email: "john@example.com", organization: organization)
      donation1 = participant.donations.create!(organization: organization)
      donation2 = participant.donations.create!(organization: organization)
      allow(donation1.line_items).to receive(:total).and_return(10)
      allow(donation2.line_items).to receive(:total).and_return(20)
      expect(participant.volume).to eq(30)
    end
  end

  describe "#volume_by_product_drive" do
    it "calculates the total volume of donations for a specific product drive" do
      organization = Organization.create!(name: "Test Org")
      participant = ProductDriveParticipant.create!(contact_name: "John Doe", phone: "1234567890", email: "john@example.com", organization: organization)
      product_drive = ProductDrive.create!(name: "Drive 1", organization: organization)
      donation1 = participant.donations.create!(product_drive: product_drive, organization: organization)
      donation2 = participant.donations.create!(product_drive_id: 2, organization: organization)
      allow(donation1.line_items).to receive(:total).and_return(10)
      allow(donation2.line_items).to receive(:total).and_return(20)
      allow(participant.donations).to receive(:by_product_drive).with(product_drive.id).and_return([donation1])
      expect(participant.volume_by_product_drive(product_drive.id)).to eq(10)
    end
  end

  describe "#donation_source_view" do
    context "when contact_name is present" do
      it "returns the formatted donation source view" do
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
