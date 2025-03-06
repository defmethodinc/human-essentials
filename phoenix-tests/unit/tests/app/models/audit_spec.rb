
require "rails_helper"

RSpec.describe Audit do
describe '#storage_locations_audited_for', :phoenix do
  let(:organization) { create(:organization) }
  let(:storage_location) { create(:storage_location, organization: organization) }
  let(:discarded_storage_location) { create(:storage_location, organization: organization, discarded_at: Time.current) }
  let(:audit) { create(:audit, organization: organization, storage_location: storage_location) }

  it 'returns storage locations that are not discarded for the organization' do
    expect(Audit.storage_locations_audited_for(organization)).to include(storage_location)
  end

  it 'does not return discarded storage locations for the organization' do
    expect(Audit.storage_locations_audited_for(organization)).not_to include(discarded_storage_location)
  end

  it 'returns an empty array when the organization has no storage locations' do
    new_organization = create(:organization)
    expect(Audit.storage_locations_audited_for(new_organization)).to be_empty
  end

  it 'returns only non-discarded storage locations when some are discarded' do
    expect(Audit.storage_locations_audited_for(organization)).to eq([storage_location])
  end

  it 'handles the case where the organization does not exist' do
    non_existent_organization = build(:organization)
    expect(Audit.storage_locations_audited_for(non_existent_organization)).to be_empty
  end
end
describe '#finalized_since?', :phoenix do
  let(:organization) { create(:organization) }
  let(:storage_location) { create(:storage_location, organization: organization) }
  let(:item) { create(:item) }
  let(:donation) { create(:donation, organization: organization, storage_location: storage_location, issued_at: 1.day.ago) }
  let(:audit) { create(:audit, :with_items, organization: organization, storage_location: storage_location, status: :finalized, item: item) }

  it 'returns true when audits match all conditions' do
    allow(donation).to receive(:line_items).and_return([build(:line_item, item: item, itemizable: donation)])
    expect(Audit.finalized_since?(donation, storage_location.id)).to be true
  end

  describe 'when no audits have the finalized status' do
    before { audit.update(status: :in_progress) }

    it 'returns false' do
      expect(Audit.finalized_since?(donation, storage_location.id)).to be false
    end
  end

  describe 'when audits are not in the specified location IDs' do
    let(:other_location) { create(:storage_location, organization: organization) }

    it 'returns false' do
      expect(Audit.finalized_since?(donation, other_location.id)).to be false
    end
  end

  describe 'when audits are updated before the itemizable created_at' do
    before { audit.update(updated_at: 2.days.ago) }

    it 'returns false' do
      expect(Audit.finalized_since?(donation, storage_location.id)).to be false
    end
  end

  describe 'when no line items match the item IDs' do
    before { allow(donation).to receive(:line_items).and_return([]) }

    it 'returns false' do
      expect(Audit.finalized_since?(donation, storage_location.id)).to be false
    end
  end
end
describe "#user_is_organization_admin_of_the_organization", :phoenix do
  let(:organization) { create(:organization) }
  let(:user) { create(:user) }
  let(:audit) { build(:audit, organization: organization, user: user) }

  it "returns without error when organization is nil" do
    audit.organization = nil
    audit.user_is_organization_admin_of_the_organization
    expect(audit.errors[:user]).to be_empty
  end

  context "when organization is not nil" do
    let(:user_with_role) { create(:user) }
    let(:user_without_role) { create(:user) }

    before do
      allow(user_with_role).to receive(:has_role?).with(Role::ORG_ADMIN, organization).and_return(true)
      allow(user_without_role).to receive(:has_role?).with(Role::ORG_ADMIN, organization).and_return(false)
    end

    it "does not add error when user has ORG_ADMIN role" do
      audit.user = user_with_role
      audit.user_is_organization_admin_of_the_organization
      expect(audit.errors[:user]).to be_empty
    end

    it "adds error when user does not have ORG_ADMIN role" do
      audit.user = user_without_role
      audit.user_is_organization_admin_of_the_organization
      expect(audit.errors[:user]).to include("user must be an organization admin of the organization")
    end
  end
end
describe "#line_items_unique_by_item_id", :phoenix do
  let(:organization) { create(:organization) }
  let(:storage_location) { create(:storage_location, organization: organization) }
  let(:audit) { build(:audit, organization: organization, storage_location: storage_location) }

  context "when there are no line items" do
    it "does not add any errors" do
      audit.line_items_unique_by_item_id
      expect(audit.errors[:base]).to be_empty
    end
  end

  context "when all item IDs are unique" do
    let(:unique_item) { create(:item, organization: organization) }
    before do
      audit.line_items << build(:line_item, item: unique_item, itemizable: audit)
    end

    it "does not add any errors" do
      audit.line_items_unique_by_item_id
      expect(audit.errors[:base]).to be_empty
    end
  end

  context "when there are duplicate item IDs" do
    let(:duplicate_item) { create(:item, organization: organization) }
    before do
      2.times { audit.line_items << build(:line_item, item: duplicate_item, itemizable: audit) }
    end

    it "adds an error for duplicate item IDs" do
      audit.line_items_unique_by_item_id
      expect(audit.errors[:base]).to include("You have entered at least one duplicate item: #{duplicate_item.name}")
    end
  end

  context "when there are multiple sets of duplicate item IDs" do
    let(:duplicate_item1) { create(:item, organization: organization) }
    let(:duplicate_item2) { create(:item, organization: organization) }
    before do
      2.times { audit.line_items << build(:line_item, item: duplicate_item1, itemizable: audit) }
      2.times { audit.line_items << build(:line_item, item: duplicate_item2, itemizable: audit) }
    end

    it "adds an error for each set of duplicate item IDs" do
      audit.line_items_unique_by_item_id
      expect(audit.errors[:base]).to include("You have entered at least one duplicate item: #{duplicate_item1.name}, #{duplicate_item2.name}")
    end
  end
end
describe '#line_items_quantity_is_not_negative', :phoenix do
  let(:audit) { build(:audit, :with_items, item_quantity: item_quantity) }

  context 'when quantity is 0' do
    let(:item_quantity) { 0 }

    it 'returns true for quantity of 0' do
      expect(audit.line_items_quantity_is_not_negative).to be_truthy
    end
  end

  context 'when quantity is positive' do
    let(:item_quantity) { 10 }

    it 'returns true for positive quantity' do
      expect(audit.line_items_quantity_is_not_negative).to be_truthy
    end
  end

  context 'when quantity is negative' do
    let(:item_quantity) { -5 }

    it 'returns false for negative quantity' do
      expect(audit.line_items_quantity_is_not_negative).to be_falsey
    end
  end
end
end
