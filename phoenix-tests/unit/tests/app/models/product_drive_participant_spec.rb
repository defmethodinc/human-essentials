require "rails_helper"

RSpec.describe ProductDriveParticipant, type: :model do
  let(:participant) { described_class.new }

  describe "validations" do
    context "when phone is blank" do
      it "requires email to be present" do
        participant.phone = nil
        participant.email = nil
        participant.valid?
        expect(participant.errors[:email]).to include("Must provide a phone or an e-mail")
      end
    end

    context "when email is blank" do
      it "requires phone to be present" do
        participant.email = nil
        participant.phone = nil
        participant.valid?
        expect(participant.errors[:phone]).to include("Must provide a phone or an e-mail")
      end
    end

    context "when contact_name is blank" do
      it "requires business_name to be present" do
        participant.contact_name = nil
        participant.business_name = nil
        participant.valid?
        expect(participant.errors[:business_name]).to include("Must provide a name or a business name")
      end
    end

    context "when business_name is blank" do
      it "requires contact_name to be present" do
        participant.business_name = nil
        participant.contact_name = nil
        participant.valid?
        expect(participant.errors[:contact_name]).to include("Must provide a name or a business name")
      end
    end

    it "validates comment length to be at most 500 characters" do
      participant.comment = "a" * 501
      participant.valid?
      expect(participant.errors[:comment]).to include("is too long (maximum is 500 characters)")
    end
  end

  describe "associations" do
    it "has many donations" do
      association = described_class.reflect_on_association(:donations)
      expect(association.macro).to eq(:has_many)
    end
  end

  describe "scopes" do
    describe ".alphabetized" do
      it "orders by contact_name" do
        organization = create(:organization)
        participant1 = described_class.create!(contact_name: "Zeta", email: "zeta@example.com", organization: organization)
        participant2 = described_class.create!(contact_name: "Alpha", email: "alpha@example.com", organization: organization)
        expect(described_class.alphabetized).to eq([participant2, participant1])
      end
    end
  end

  describe "#volume" do
    it "calculates the total volume of donations" do
      participant = create(:product_drive_participant)
      donation1 = create(:donation, product_drive_participant: participant)
      donation2 = create(:donation, product_drive_participant: participant)
      allow(donation1.line_items).to receive(:total).and_return(10)
      allow(donation2.line_items).to receive(:total).and_return(20)
      expect(participant.volume).to eq(30)
    end
  end

  describe "#volume_by_product_drive" do
    it "calculates the total volume of donations for a specific product drive" do
      participant = create(:product_drive_participant)
      product_drive = create(:product_drive)
      donation1 = create(:donation, product_drive_participant: participant, product_drive: product_drive)
      donation2 = create(:donation, product_drive_participant: participant, product_drive: product_drive)
      allow(donation1.line_items).to receive(:total).and_return(15)
      allow(donation2.line_items).to receive(:total).and_return(25)
      expect(participant.volume_by_product_drive(product_drive.id)).to eq(40)
    end
  end

  describe "#donation_source_view" do
    context "when contact_name is present" do
      it "returns the contact name with participant label" do
        participant.contact_name = "John Doe"
        expect(participant.donation_source_view).to eq("John Doe (participant)")
      end
    end

    context "when contact_name is blank" do
      it "returns nil" do
        participant.contact_name = nil
        expect(participant.donation_source_view).to be_nil
      end
    end
  end
end
