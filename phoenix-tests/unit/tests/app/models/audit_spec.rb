require "rails_helper"

RSpec.describe Audit, type: :model do
  let(:organization) { create(:organization) }
  let(:user) { create(:user) }
  let(:storage_location) { create(:storage_location, organization: organization) }
  let(:audit) { build(:audit, organization: organization, user: user, storage_location: storage_location) }
  let(:item) { create(:item) }
  let(:line_item) { build(:line_item, item: item, quantity: 5) }

  before do
    allow(user).to receive(:has_role?).with(Role::ORG_ADMIN, organization).and_return(true)
    audit.line_items << line_item
  end

  describe "validations" do
    it "validates presence of storage_location" do
      audit.storage_location = nil
      expect(audit).not_to be_valid
      expect(audit.errors[:storage_location]).to include("can't be blank")
    end

    it "validates presence of organization" do
      audit.organization = nil
      expect(audit).not_to be_valid
      expect(audit.errors[:organization]).to include("can't be blank")
    end

    it "validates line_items_quantity_is_not_negative" do
      audit.line_items.first.quantity = -1
      expect(audit).not_to be_valid
      expect(audit.errors[:line_items]).to include("quantity must be at least 0")
    end

    it "validates line_items_unique_by_item_id" do
      duplicate_line_item = build(:line_item, item: item, quantity: 3)
      audit.line_items << duplicate_line_item
      expect(audit).not_to be_valid
      expect(audit.errors[:base]).to include("You have entered at least one duplicate item: #{item.name}")
    end

    it "validates user_is_organization_admin_of_the_organization" do
      allow(user).to receive(:has_role?).with(Role::ORG_ADMIN, organization).and_return(false)
      expect(audit).not_to be_valid
      expect(audit.errors[:user]).to include("user must be an organization admin of the organization")
    end
  end

  describe "scopes" do
    describe ".at_location" do
      it "returns audits at the specified location" do
        audit.save!
        another_audit = create(:audit, organization: organization, user: user, storage_location: create(:storage_location, organization: organization))
        expect(Audit.at_location(storage_location.id)).to include(audit)
        expect(Audit.at_location(storage_location.id)).not_to include(another_audit)
      end
    end
  end

  describe "class methods" do
    describe ".storage_locations_audited_for" do
      it "returns storage locations audited for the organization" do
        audit.save!
        expect(Audit.storage_locations_audited_for(organization)).to include(storage_location)
      end
    end

    describe ".finalized_since?" do
      it "checks if audits have been finalized since a given time" do
        audit.update(status: :finalized, updated_at: 1.day.ago)
        itemizable = double("itemizable", line_items: [line_item], created_at: 2.days.ago)
        expect(Audit.finalized_since?(itemizable, storage_location.id)).to be true
      end
    end
  end
end
