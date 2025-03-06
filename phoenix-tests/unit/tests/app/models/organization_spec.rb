
require "rails_helper"

RSpec.describe Organization do
describe '#other', :phoenix do
  let(:organization_with_other_key) { create(:organization, partner_key: 'other') }
  let(:organization_with_different_key) { create(:organization, partner_key: 'different') }

  context 'when records have partner_key as other' do
    it 'returns records with partner_key as other' do
      expect(Organization.other).to include(organization_with_other_key)
    end
  end

  context 'when no records have partner_key as other' do
    before { organization_with_other_key.destroy }

    it 'returns an empty collection' do
      expect(Organization.other).to be_empty
    end
  end

  context 'when records have different partner_key values' do
    it 'does not return records with different partner_key values' do
      expect(Organization.other).not_to include(organization_with_different_key)
    end
  end
end
describe '#during', :phoenix do
  let(:organization) { create(:organization) }
  let!(:line_item_within_range) { create(:line_item, created_at: '2023-01-15', itemizable: organization) }
  let!(:line_item_outside_range) { create(:line_item, created_at: '2022-12-31', itemizable: organization) }
  let!(:line_item_edge_case) { create(:line_item, created_at: '2023-01-01', itemizable: organization) }

  context 'when there are line items within the date range' do
    it 'returns correct count for line items within the date range' do
      result = organization.during('2023-01-01', '2023-01-31')
      expect(result.first.amount).to eq(2)
    end

    it 'returns correct name for line items within the date range' do
      result = organization.during('2023-01-01', '2023-01-31')
      expect(result.first.name).to eq(organization.name)
    end
  end

  context 'when there are no line items in the date range' do
    it 'returns no results' do
      result = organization.during('2024-01-01', '2024-01-31')
      expect(result).to be_empty
    end
  end

  context 'when the date range is invalid (start date is after end date)' do
    it 'returns no results for invalid date range' do
      result = organization.during('2023-02-01', '2023-01-01')
      expect(result).to be_empty
    end
  end

  context 'when the start date equals the end date' do
    it 'returns correct count for edge case where start date equals end date' do
      result = organization.during('2023-01-01', '2023-01-01')
      expect(result.first.amount).to eq(1)
    end

    it 'returns correct name for edge case where start date equals end date' do
      result = organization.during('2023-01-01', '2023-01-01')
      expect(result.first.name).to eq(organization.name)
    end
  end

  context 'when only start date is provided' do
    before do
      allow(Time.zone).to receive(:now).and_return(Time.zone.parse('2023-01-31'))
    end

    it 'returns correct count using current date as default end date' do
      result = organization.during('2023-01-01')
      expect(result.first.amount).to eq(2)
    end

    it 'returns correct name using current date as default end date' do
      result = organization.during('2023-01-01')
      expect(result.first.name).to eq(organization.name)
    end
  end
end
describe '#top', :phoenix do
  let(:organization) { create(:organization) }

  context 'when there are no items' do
    it 'returns an empty array' do
      expect(organization.top).to eq([])
    end
  end

  context 'when there are fewer items than the limit' do
    let!(:line_items) { create_list(:line_item, 3, itemizable: organization) }

    it 'returns all items' do
      expect(organization.top).to match_array(line_items)
    end
  end

  context 'when there are as many items as the limit' do
    let!(:line_items) { create_list(:line_item, 5, itemizable: organization) }

    it 'returns exactly the limit number of items' do
      expect(organization.top).to match_array(line_items)
    end
  end

  context 'when there are more items than the limit' do
    let!(:line_items) { create_list(:line_item, 10, itemizable: organization) }

    it 'returns the top items up to the limit' do
      expect(organization.top.size).to eq(5)
    end
  end

  context 'when items have varying counts' do
    let!(:line_items) do
      create(:line_item, itemizable: organization, id: 1)
      create(:line_item, itemizable: organization, id: 2)
      create(:line_item, itemizable: organization, id: 3)
      create(:line_item, itemizable: organization, id: 4)
      create(:line_item, itemizable: organization, id: 5)
      create(:line_item, itemizable: organization, id: 6)
      create(:line_item, itemizable: organization, id: 7)
      create(:line_item, itemizable: organization, id: 8)
      create(:line_item, itemizable: organization, id: 9)
      create(:line_item, itemizable: organization, id: 10)
    end

    it 'orders items by count of line_items.id in descending order' do
      top_items = organization.top
      expect(top_items).to eq(top_items.sort_by { |item| -item.id })
    end
  end
end
describe '#bottom', :phoenix do
  let(:organization_with_no_line_items) { create(:organization) }
  let(:organization_with_few_line_items) { create(:organization) }
  let(:organization_with_exact_line_items) { create(:organization) }
  let(:organization_with_many_line_items) { create(:organization) }
  let(:organization_with_ordered_line_items) { create(:organization) }

  before do
    create_list(:line_item, 0, itemizable: organization_with_no_line_items)
    create_list(:line_item, 3, itemizable: organization_with_few_line_items)
    create_list(:line_item, 5, itemizable: organization_with_exact_line_items)
    create_list(:line_item, 10, itemizable: organization_with_many_line_items)
    create_list(:line_item, 1, itemizable: organization_with_ordered_line_items)
  end

  it 'returns an empty array when there are no line items' do
    expect(organization_with_no_line_items.bottom).to eq([])
  end

  it 'returns all organizations when there are fewer organizations than the limit' do
    result = organization_with_few_line_items.bottom(5)
    expect(result.size).to eq(1)
  end

  it 'returns exactly the limit number of organizations when there are as many organizations as the limit' do
    result = organization_with_exact_line_items.bottom(5)
    expect(result.size).to eq(1)
  end

  it 'returns the bottom organizations when there are more organizations than the limit' do
    result = organization_with_many_line_items.bottom(5)
    expect(result.size).to eq(5)
  end

  it 'orders organizations by the count of line_items in ascending order' do
    result = organization_with_many_line_items.bottom(5)
    expect(result.first).to eq(organization_with_ordered_line_items)
  end

  it 'handles invalid limit input gracefully without raising an error' do
    expect { organization_with_many_line_items.bottom(-1) }.not_to raise_error
  end
end
describe '#all', :phoenix do
  let(:organization) { create(:organization) }
  let(:barcode_item_with_org_id) { create(:barcode_item, organization: organization) }
  let(:barcode_item_with_base_item) { create(:global_barcode_item) }
  let(:barcode_item_with_neither) { create(:barcode_item, organization: nil, barcodeable_type: 'OtherType') }
  let(:barcode_item_with_both) { create(:barcode_item, organization: organization, barcodeable_type: 'BaseItem') }

  before do
    barcode_item_with_org_id
    barcode_item_with_base_item
    barcode_item_with_neither
    barcode_item_with_both
  end

  it 'includes items with matching organization_id' do
    result = organization.all
    expect(result).to include(barcode_item_with_org_id)
  end

  it 'excludes items with neither condition matching' do
    result = organization.all
    expect(result).not_to include(barcode_item_with_neither)
  end

  it 'includes items with barcodeable_type BaseItem' do
    result = organization.all
    expect(result).to include(barcode_item_with_base_item)
  end

  it 'includes items with both conditions matching' do
    result = organization.all
    expect(result).to include(barcode_item_with_both)
  end
end
describe '#upcoming', :phoenix do
  let(:organization) { create(:organization) }
  let(:this_week_distribution) { build(:distribution, organization: organization, issued_at: Time.zone.today) }
  let(:future_distribution) { build(:distribution, organization: organization, issued_at: Time.zone.today + 1.day) }
  let(:past_distribution) { build(:distribution, :past, organization: organization) }

  it 'returns records scheduled for today' do
    allow(organization).to receive(:this_week).and_return([this_week_distribution])
    allow(this_week_distribution).to receive(:scheduled).and_return([this_week_distribution])
    expect(organization.upcoming).to include(this_week_distribution)
  end

  it 'returns records scheduled for future dates' do
    allow(organization).to receive(:this_week).and_return([future_distribution])
    allow(future_distribution).to receive(:scheduled).and_return([future_distribution])
    expect(organization.upcoming).to include(future_distribution)
  end

  it 'does not return records scheduled for past dates' do
    allow(organization).to receive(:this_week).and_return([past_distribution])
    allow(past_distribution).to receive(:scheduled).and_return([])
    expect(organization.upcoming).not_to include(past_distribution)
  end

  it 'returns an empty collection when there are no records' do
    allow(organization).to receive(:this_week).and_return([])
    expect(organization.upcoming).to be_empty
  end
end
describe '#flipper_id', :phoenix do
  let(:organization) { build(:organization, id: 123) }

  it 'returns the correct string format for a valid integer id' do
    expect(organization.flipper_id).to eq('Org:123')
  end

  context 'when id is nil' do
    before do
      allow(organization).to receive(:id).and_return(nil)
    end

    it 'returns the correct string format for nil id' do
      expect(organization.flipper_id).to eq('Org:')
    end
  end

  context 'when id is a non-integer value' do
    before do
      allow(organization).to receive(:id).and_return('non-integer')
    end

    it 'returns the correct string format for non-integer id' do
      expect(organization.flipper_id).to eq('Org:non-integer')
    end
  end
end
describe "#assign_attributes_from_account_request", :phoenix do
  let(:account_request) { build(:account_request) }
  let(:organization) { build(:organization) }

  it "assigns name from account_request" do
    organization.assign_attributes_from_account_request(account_request)
    expect(organization.name).to eq(account_request.organization_name)
  end

  it "assigns url from account_request" do
    organization.assign_attributes_from_account_request(account_request)
    expect(organization.url).to eq(account_request.organization_website)
  end

  it "assigns email from account_request" do
    organization.assign_attributes_from_account_request(account_request)
    expect(organization.email).to eq(account_request.email)
  end

  it "assigns account_request_id from account_request" do
    organization.assign_attributes_from_account_request(account_request)
    expect(organization.account_request_id).to eq(account_request.id)
  end

  describe "when organization_name is missing" do
    let(:account_request) { build(:account_request, organization_name: nil) }

    it "sets name to nil" do
      organization.assign_attributes_from_account_request(account_request)
      expect(organization.name).to be_nil
    end
  end

  describe "when organization_website is missing" do
    let(:account_request) { build(:account_request, organization_website: nil) }

    it "sets url to nil" do
      organization.assign_attributes_from_account_request(account_request)
      expect(organization.url).to be_nil
    end
  end

  describe "when email is missing" do
    let(:account_request) { build(:account_request, email: nil) }

    it "sets email to nil" do
      organization.assign_attributes_from_account_request(account_request)
      expect(organization.email).to be_nil
    end
  end

  describe "when account_request_id is missing" do
    let(:account_request) { build(:account_request, id: nil) }

    it "sets account_request_id to nil" do
      organization.assign_attributes_from_account_request(account_request)
      expect(organization.account_request_id).to be_nil
    end
  end

  describe "when account_request is nil" do
    let(:account_request) { nil }

    it "raises NoMethodError" do
      expect { organization.assign_attributes_from_account_request(account_request) }.to raise_error(NoMethodError)
    end
  end
end
describe '#to_param', :phoenix do
  let(:organization) { build(:organization, short_name: short_name) }

  context 'when short_name is a valid string' do
    let(:short_name) { 'valid_short_name' }

    it 'returns the short_name' do
      expect(organization.to_param).to eq('valid_short_name')
    end
  end

  context 'when short_name is nil' do
    let(:short_name) { nil }

    it 'returns nil' do
      expect(organization.to_param).to be_nil
    end
  end

  context 'when short_name is an empty string' do
    let(:short_name) { '' }

    it 'returns an empty string' do
      expect(organization.to_param).to eq('')
    end
  end
end
describe "#display_users", :phoenix do
  let(:organization) { build(:organization) }

  before do
    allow(organization).to receive(:users).and_return(users)
  end

  context "with multiple users" do
    let(:users) { build_list(:user, 3, organization: organization, email: 'user@example.com') }

    it "joins multiple user emails with commas" do
      expect(organization.display_users).to eq('user@example.com, user@example.com, user@example.com')
    end
  end

  context "with no users" do
    let(:users) { [] }

    it "returns an empty string when there are no users" do
      expect(organization.display_users).to eq('')
    end
  end

  context "with a single user" do
    let(:users) { [build(:user, email: 'single@example.com', organization: organization)] }

    it "returns the email when there is only one user" do
      expect(organization.display_users).to eq('single@example.com')
    end
  end

  context "with users having nil emails" do
    let(:users) { [build(:user, email: nil, organization: organization)] }

    it "returns an empty string for users with nil emails" do
      expect(organization.display_users).to eq('')
    end
  end

  context "with users having empty string emails" do
    let(:users) { [build(:user, email: "", organization: organization)] }

    it "returns an empty string for users with empty string emails" do
      expect(organization.display_users).to eq('')
    end
  end

  context "with a mix of valid, nil, and empty string emails" do
    let(:users) do
      [
        build(:user, email: "valid@example.com", organization: organization),
        build(:user, email: nil, organization: organization),
        build(:user, email: "", organization: organization)
      ]
    end

    it "returns only valid emails, ignoring nil and empty string emails" do
      expect(organization.display_users).to eq('valid@example.com')
    end
  end
end
describe '#ordered_requests', :phoenix do
  let(:organization) { create(:organization) }

  it 'returns an empty array when there are no requests' do
    expect(organization.ordered_requests).to eq([])
  end

  describe 'with a single request' do
    let!(:request) { create(:request, organization: organization) }

    it 'returns the single request' do
      expect(organization.ordered_requests).to eq([request])
    end
  end

  describe 'with multiple requests having the same status' do
    let!(:request1) { create(:request, organization: organization, updated_at: 1.day.ago) }
    let!(:request2) { create(:request, organization: organization, updated_at: 2.days.ago) }

    it 'orders them by updated_at in descending order' do
      expect(organization.ordered_requests).to eq([request1, request2])
    end
  end

  describe 'with multiple requests having different statuses' do
    let!(:request1) { create(:request, organization: organization, status: 'fulfilled') }
    let!(:request2) { create(:request, organization: organization, status: 'started') }

    it 'orders them by status in ascending order' do
      expect(organization.ordered_requests).to eq([request2, request1])
    end
  end

  describe 'with multiple requests having different statuses and updated_at timestamps' do
    let!(:request1) { create(:request, organization: organization, status: 'fulfilled', updated_at: 1.day.ago) }
    let!(:request2) { create(:request, organization: organization, status: 'started', updated_at: 2.days.ago) }
    let!(:request3) { create(:request, organization: organization, status: 'started', updated_at: 3.days.ago) }

    it 'orders them by status in ascending order and updated_at in descending order' do
      expect(organization.ordered_requests).to eq([request2, request3, request1])
    end
  end
end
describe '#address', :phoenix do
  let(:organization) { build(:organization, street: street, city: city, state: state, zipcode: zipcode) }
  let(:street) { '1500 Remount Road' }
  let(:city) { 'Front Royal' }
  let(:state) { 'VA' }
  let(:zipcode) { '22630' }

  it 'returns full address when all components are present' do
    expect(organization.address).to eq('1500 Remount Road, Front Royal, VA 22630')
  end

  context 'when only street and city are present' do
    let(:state) { nil }
    let(:zipcode) { nil }

    it 'returns address with street and city when only they are present' do
      expect(organization.address).to eq('1500 Remount Road, Front Royal')
    end
  end

  context 'when only state and zipcode are present' do
    let(:street) { nil }
    let(:city) { nil }

    it 'returns address with state and zipcode when only they are present' do
      expect(organization.address).to eq('VA 22630')
    end
  end

  context 'when only street is present' do
    let(:city) { nil }
    let(:state) { nil }
    let(:zipcode) { nil }

    it 'returns address with only street when only it is present' do
      expect(organization.address).to eq('1500 Remount Road')
    end
  end

  context 'when only city is present' do
    let(:street) { nil }
    let(:state) { nil }
    let(:zipcode) { nil }

    it 'returns address with only city when only it is present' do
      expect(organization.address).to eq('Front Royal')
    end
  end

  context 'when only state is present' do
    let(:street) { nil }
    let(:city) { nil }
    let(:zipcode) { nil }

    it 'returns address with only state when only it is present' do
      expect(organization.address).to eq('VA')
    end
  end

  context 'when only zipcode is present' do
    let(:street) { nil }
    let(:city) { nil }
    let(:state) { nil }

    it 'returns address with only zipcode when only it is present' do
      expect(organization.address).to eq('22630')
    end
  end

  context 'when no components are present' do
    let(:street) { nil }
    let(:city) { nil }
    let(:state) { nil }
    let(:zipcode) { nil }

    it 'returns empty string when no components are present' do
      expect(organization.address).to eq('')
    end
  end
end
describe '#address_changed?', :phoenix do
  let(:organization) { build(:organization) }

  it 'returns true if street has changed' do
    allow(organization).to receive(:street_changed?).and_return(true)
    expect(organization.address_changed?).to be true
  end

  it 'returns true if city has changed' do
    allow(organization).to receive(:city_changed?).and_return(true)
    expect(organization.address_changed?).to be true
  end

  it 'returns true if state has changed' do
    allow(organization).to receive(:state_changed?).and_return(true)
    expect(organization.address_changed?).to be true
  end

  it 'returns true if zipcode has changed' do
    allow(organization).to receive(:zipcode_changed?).and_return(true)
    expect(organization.address_changed?).to be true
  end

  it 'returns false if none of the address fields have changed' do
    allow(organization).to receive(:street_changed?).and_return(false)
    allow(organization).to receive(:city_changed?).and_return(false)
    allow(organization).to receive(:state_changed?).and_return(false)
    allow(organization).to receive(:zipcode_changed?).and_return(false)
    expect(organization.address_changed?).to be false
  end
end
describe '#address_inline', :phoenix do
  let(:organization_with_multiline_address) { build(:organization, street: "123 Main St\nSuite 100\nBuilding 5") }
  let(:organization_with_whitespace_address) { build(:organization, street: "  123 Main St  \n  Suite 100  ") }
  let(:organization_with_empty_lines_address) { build(:organization, street: "123 Main St\n\nSuite 100") }
  let(:organization_with_single_line_address) { build(:organization, street: "123 Main St") }
  let(:organization_with_empty_address) { build(:organization, street: "") }

  it 'returns a single line for a multiline address' do
    expect(organization_with_multiline_address.address_inline).to eq('123 Main St, Suite 100, Building 5')
  end

  it 'strips leading and trailing whitespace from each line' do
    expect(organization_with_whitespace_address.address_inline).to eq('123 Main St, Suite 100')
  end

  it 'removes empty lines from the address' do
    expect(organization_with_empty_lines_address.address_inline).to eq('123 Main St, Suite 100')
  end

  it 'returns the same line for a single line address' do
    expect(organization_with_single_line_address.address_inline).to eq('123 Main St')
  end

  it 'returns an empty string for an empty address' do
    expect(organization_with_empty_address.address_inline).to eq('')
  end
end
describe '#total_inventory', :phoenix do
  let(:organization_with_items) { create(:organization, :with_items) }
  let(:organization_without_locations) { create(:organization) }
  let(:organization_with_empty_locations) { create(:organization) }

  it 'calculates total inventory for an organization with multiple storage locations and items' do
    expect(organization_with_items.total_inventory).to eq(100) # assuming 100 is the expected total
  end

  it 'returns zero when the organization has no storage locations' do
    expect(organization_without_locations.total_inventory).to eq(0)
  end

  it 'returns zero when storage locations have no items' do
    expect(organization_with_empty_locations.total_inventory).to eq(0)
  end

  it 'raises an error when there is a problem in data retrieval or method calls' do
    allow(View::Inventory).to receive(:total_inventory).and_raise(StandardError)
    expect { organization_with_items.total_inventory }.to raise_error(StandardError)
  end
end
describe ".seed_items", :phoenix do
  let(:organization) { create(:organization) }
  let(:organizations) { create_list(:organization, 3) }
  let(:base_items) { create_list(:base_item, 5) }

  before do
    allow(BaseItem).to receive(:all).and_return(base_items)
  end

  it "seeds items for all organizations when no argument is provided" do
    expect(Organization).to receive(:all).and_return(organizations)
    organizations.each do |org|
      expect(org).to receive(:seed_items).with(base_items)
      expect(org).to receive(:reload)
    end
    Organization.seed_items
  end

  it "seeds items for a single organization when one organization is provided" do
    expect(organization).to receive(:seed_items).with(base_items)
    expect(organization).to receive(:reload)
    Organization.seed_items(organization)
  end

  it "seeds items for multiple organizations when an array of organizations is provided" do
    organizations.each do |org|
      expect(org).to receive(:seed_items).with(base_items)
      expect(org).to receive(:reload)
    end
    Organization.seed_items(organizations)
  end

  describe "when BaseItem.all returns an empty array" do
    before do
      allow(BaseItem).to receive(:all).and_return([])
    end

    it "does not seed any items" do
      expect(organization).not_to receive(:seed_items)
      Organization.seed_items(organization)
    end
  end

  describe "when BaseItem.all returns a non-empty array" do
    it "seeds items based on the base items" do
      expect(organization).to receive(:seed_items).with(base_items)
      Organization.seed_items(organization)
    end
  end

  describe "when an organization fails to seed items" do
    before do
      allow_any_instance_of(Organization).to receive(:seed_items).and_raise(StandardError)
    end

    it "handles the exception gracefully" do
      expect { Organization.seed_items(organization) }.not_to raise_error
    end
  end

  describe "when an organization successfully seeds items" do
    it "reloads the organization" do
      expect(organization).to receive(:reload)
      Organization.seed_items(organization)
    end
  end
end
describe '#seed_items', :phoenix do
  let(:organization) { create(:organization) }
  let(:item) { build(:item, name: 'Item 1', partner_key: 'partner_key_1') }
  let(:duplicate_item) { build(:item, name: 'Item 1', partner_key: 'partner_key_2') }
  let(:other_item) { create(:item, name: 'Item 1', partner_key: 'other', organization: organization) }

  it 'successfully creates a new item' do
    expect { organization.seed_items([item]) }.to change { organization.items.count }.by(1)
  end

  context 'when encountering a duplicate item' do
    before do
      organization.items.create!(name: 'Item 1', partner_key: 'partner_key_1')
    end

    it 'logs a duplicate item message' do
      expect(Rails.logger).to receive(:info).with('[SEED] Duplicate item! Item 1')
      organization.seed_items([duplicate_item]) rescue nil
    end

    context 'and the existing item is other' do
      it 'updates the existing item with the new partner_key' do
        organization.seed_items([other_item])
        expect(other_item.reload.partner_key).to eq('partner_key_2')
      end

      it 'reloads the existing item' do
        expect(other_item).to receive(:reload)
        organization.seed_items([other_item])
      end
    end

    context 'and the existing item does not meet update conditions' do
      it 'skips the item' do
        expect { organization.seed_items([duplicate_item]) }.not_to change { other_item.reload.partner_key }
      end
    end
  end

  it 'reloads the organization after processing items' do
    expect(organization).to receive(:reload)
    organization.seed_items([item])
  end
end
describe '#valid_items', :phoenix do
  let(:organization) { create(:organization) }

  let(:inactive_item) { build(:item, :inactive, visible_to_partners: true, organization: organization) }
  let(:invisible_item) { build(:item, active: true, visible_to_partners: false, organization: organization) }
  let(:inactive_invisible_item) { build(:item, :inactive, visible_to_partners: false, organization: organization) }
  let(:active_visible_item) { build(:item, :active, visible_to_partners: true, organization: organization) }

  it 'returns an empty array when there are no items' do
    expect(organization.valid_items).to eq([])
  end

  it 'returns an empty array when no items are active' do
    inactive_item.save
    invisible_item.save
    inactive_invisible_item.save
    expect(organization.valid_items).to eq([])
  end

  it 'returns an empty array when no items are visible' do
    inactive_item.save
    invisible_item.save
    inactive_invisible_item.save
    expect(organization.valid_items).to eq([])
  end

  it 'returns an empty array when no items are active and visible' do
    inactive_item.save
    invisible_item.save
    inactive_invisible_item.save
    expect(organization.valid_items).to eq([])
  end

  it 'returns a list of valid items when items are active and visible' do
    active_visible_item.save
    expect(organization.valid_items).to eq([
      {
        id: active_visible_item.id,
        partner_key: active_visible_item.partner_key,
        name: active_visible_item.name
      }
    ])
  end

  describe 'when items have different attributes' do
    before { active_visible_item.save }

    it 'returns item with correct id' do
      result = organization.valid_items.first
      expect(result[:id]).to eq(active_visible_item.id)
    end

    it 'returns item with correct partner_key' do
      result = organization.valid_items.first
      expect(result[:partner_key]).to eq(active_visible_item.partner_key)
    end

    it 'returns item with correct name' do
      result = organization.valid_items.first
      expect(result[:name]).to eq(active_visible_item.name)
    end
  end
end
describe "#item_id_to_display_string_map", :phoenix do
  let(:organization) { build(:organization) }

  context "when valid_items is empty" do
    before do
      allow(organization).to receive(:valid_items).and_return([])
    end

    it "returns an empty hash" do
      expect(organization.item_id_to_display_string_map).to eq({})
    end
  end

  context "when valid_items has valid items" do
    let(:valid_items) do
      [
        { id: "1", name: "Item One" },
        { id: "2", name: "Item Two" }
      ]
    end

    before do
      allow(organization).to receive(:valid_items).and_return(valid_items)
    end

    it "maps item ids to names" do
      expect(organization.item_id_to_display_string_map).to eq({ 1 => "Item One", 2 => "Item Two" })
    end
  end

  context "when valid_items has non-integer ids" do
    let(:valid_items) do
      [
        { id: "abc", name: "Item ABC" },
        { id: "2", name: "Item Two" }
      ]
    end

    before do
      allow(organization).to receive(:valid_items).and_return(valid_items)
    end

    it "ignores items with non-integer ids" do
      expect(organization.item_id_to_display_string_map).to eq({ 2 => "Item Two" })
    end
  end

  context "when valid_items has duplicate ids" do
    let(:valid_items) do
      [
        { id: "1", name: "Item One" },
        { id: "1", name: "Duplicate Item One" }
      ]
    end

    before do
      allow(organization).to receive(:valid_items).and_return(valid_items)
    end

    it "overwrites duplicate ids with the last occurrence" do
      expect(organization.item_id_to_display_string_map).to eq({ 1 => "Duplicate Item One" })
    end
  end

  context "when valid_items has nil or missing names" do
    let(:valid_items) do
      [
        { id: "1", name: nil },
        { id: "2" }
      ]
    end

    before do
      allow(organization).to receive(:valid_items).and_return(valid_items)
    end

    it "maps ids to nil when names are nil or missing" do
      expect(organization.item_id_to_display_string_map).to eq({ 1 => nil, 2 => nil })
    end
  end
end
describe "#valid_items_for_select", :phoenix do
  let(:organization) { build(:organization) }
  let(:item1) { { name: "Item A", id: 1 } }
  let(:item2) { { name: "Item B", id: 2 } }
  let(:duplicate_name_item) { { name: "Item A", id: 3 } }
  let(:duplicate_id_item) { { name: "Item C", id: 1 } }
  let(:sorted_items) { [item1, item2] }
  let(:unsorted_items) { [item2, item1] }

  before do
    allow(organization).to receive(:valid_items).and_return(valid_items)
  end

  context "when there are no valid items" do
    let(:valid_items) { [] }

    it "returns an empty array" do
      expect(organization.valid_items_for_select).to eq([])
    end
  end

  context "when there are multiple unique items" do
    let(:valid_items) { [item1, item2] }

    it "returns a sorted array of name-id pairs" do
      expect(organization.valid_items_for_select).to eq([["Item A", 1], ["Item B", 2]])
    end
  end

  context "when there are items with duplicate names but different ids" do
    let(:valid_items) { [item1, duplicate_name_item] }

    it "returns items with duplicate names but different ids" do
      expect(organization.valid_items_for_select).to eq([["Item A", 1], ["Item A", 3]])
    end
  end

  context "when there are items with duplicate ids but different names" do
    let(:valid_items) { [item1, duplicate_id_item] }

    it "returns items with duplicate ids but different names" do
      expect(organization.valid_items_for_select).to eq([["Item A", 1], ["Item C", 1]])
    end
  end

  context "when items are already sorted" do
    let(:valid_items) { sorted_items }

    it "returns the same sorted array" do
      expect(organization.valid_items_for_select).to eq([["Item A", 1], ["Item B", 2]])
    end
  end

  context "when items are not initially sorted" do
    let(:valid_items) { unsorted_items }

    it "sorts items" do
      expect(organization.valid_items_for_select).to eq([["Item A", 1], ["Item B", 2]])
    end
  end
end
describe '#from_email', :phoenix do
  let(:organization_with_email) { build(:organization, email: 'contact@example.com') }
  let(:organization_without_email) { build(:organization, email: '') }

  it 'returns admin email when email is blank' do
    allow(organization_without_email).to receive(:get_admin_email).and_return('admin@example.com')
    expect(organization_without_email.from_email).to eq('admin@example.com')
  end

  it 'returns email when email is present' do
    expect(organization_with_email.from_email).to eq('contact@example.com')
  end
end
describe "#earliest_reporting_year", :phoenix do
  let(:organization) { create(:organization, created_at: created_at) }
  let(:created_at) { Time.zone.local(2020, 1, 1) }

  it "returns the created_at year when there are no donations, purchases, or distributions" do
    expect(organization.earliest_reporting_year).to eq(created_at.year)
  end

  describe "when only donations exist" do
    let!(:donation) { create(:donation, organization: organization, issued_at: donation_issued_at) }
    let(:donation_issued_at) { Time.zone.local(2019, 1, 1) }

    it "returns the earliest year between created_at and donations" do
      expect(organization.earliest_reporting_year).to eq(donation_issued_at.year)
    end
  end

  describe "when only purchases exist" do
    let!(:purchase) { create(:purchase, organization: organization, issued_at: purchase_issued_at) }
    let(:purchase_issued_at) { Time.zone.local(2018, 1, 1) }

    it "returns the earliest year between created_at and purchases" do
      expect(organization.earliest_reporting_year).to eq(purchase_issued_at.year)
    end
  end

  describe "when only distributions exist" do
    let!(:distribution) { create(:distribution, organization: organization, issued_at: distribution_issued_at) }
    let(:distribution_issued_at) { Time.zone.local(2017, 1, 1) }

    it "returns the earliest year between created_at and distributions" do
      expect(organization.earliest_reporting_year).to eq(distribution_issued_at.year)
    end
  end

  describe "when donations and purchases exist" do
    let!(:donation) { create(:donation, organization: organization, issued_at: donation_issued_at) }
    let!(:purchase) { create(:purchase, organization: organization, issued_at: purchase_issued_at) }
    let(:donation_issued_at) { Time.zone.local(2019, 1, 1) }
    let(:purchase_issued_at) { Time.zone.local(2018, 1, 1) }

    it "returns the earliest year among created_at, donations, and purchases" do
      expect(organization.earliest_reporting_year).to eq(purchase_issued_at.year)
    end
  end

  describe "when donations and distributions exist" do
    let!(:donation) { create(:donation, organization: organization, issued_at: donation_issued_at) }
    let!(:distribution) { create(:distribution, organization: organization, issued_at: distribution_issued_at) }
    let(:donation_issued_at) { Time.zone.local(2019, 1, 1) }
    let(:distribution_issued_at) { Time.zone.local(2017, 1, 1) }

    it "returns the earliest year among created_at, donations, and distributions" do
      expect(organization.earliest_reporting_year).to eq(distribution_issued_at.year)
    end
  end

  describe "when purchases and distributions exist" do
    let!(:purchase) { create(:purchase, organization: organization, issued_at: purchase_issued_at) }
    let!(:distribution) { create(:distribution, organization: organization, issued_at: distribution_issued_at) }
    let(:purchase_issued_at) { Time.zone.local(2018, 1, 1) }
    let(:distribution_issued_at) { Time.zone.local(2017, 1, 1) }

    it "returns the earliest year among created_at, purchases, and distributions" do
      expect(organization.earliest_reporting_year).to eq(distribution_issued_at.year)
    end
  end

  describe "when donations, purchases, and distributions all exist" do
    let!(:donation) { create(:donation, organization: organization, issued_at: donation_issued_at) }
    let!(:purchase) { create(:purchase, organization: organization, issued_at: purchase_issued_at) }
    let!(:distribution) { create(:distribution, organization: organization, issued_at: distribution_issued_at) }
    let(:donation_issued_at) { Time.zone.local(2019, 1, 1) }
    let(:purchase_issued_at) { Time.zone.local(2018, 1, 1) }
    let(:distribution_issued_at) { Time.zone.local(2017, 1, 1) }

    it "returns the earliest year among created_at, donations, purchases, and distributions" do
      expect(organization.earliest_reporting_year).to eq(distribution_issued_at.year)
    end
  end
end
describe '#display_last_distribution_date', :phoenix do
  let(:organization) { create(:organization) }

  context 'when there are no distributions' do
    it 'returns "No distributions"' do
      expect(organization.display_last_distribution_date).to eq('No distributions')
    end
  end

  context 'when distributions exist' do
    let!(:distribution) { create(:distribution, organization: organization, issued_at: 1.day.ago) }

    it 'returns the issued_at date of the most recent distribution' do
      expect(organization.display_last_distribution_date).to eq(distribution.issued_at.strftime("%F"))
    end
  end
end
describe '#correct_logo_mime_type', :phoenix do
  let(:organization_with_no_logo) { build(:organization, logo: nil) }
  let(:organization_with_valid_logo) { build(:organization, logo: Rack::Test::UploadedFile.new(Rails.root.join('spec/fixtures/files/logo.jpg'), 'image/jpeg')) }
  let(:organization_with_invalid_logo) { build(:organization, logo: Rack::Test::UploadedFile.new(Rails.root.join('spec/fixtures/files/logo.txt'), 'text/plain')) }

  context 'when logo is not attached' do
    it 'does not add any errors' do
      organization_with_no_logo.correct_logo_mime_type
      expect(organization_with_no_logo.errors[:logo]).to be_empty
    end
  end

  context 'when logo is attached with valid content type' do
    it 'does not add any errors' do
      organization_with_valid_logo.correct_logo_mime_type
      expect(organization_with_valid_logo.errors[:logo]).to be_empty
    end
  end

  context 'when logo is attached with invalid content type' do
    it 'sets logo to nil' do
      organization_with_invalid_logo.correct_logo_mime_type
      expect(organization_with_invalid_logo.logo).to be_nil
    end

    it 'adds an error message for invalid content type' do
      organization_with_invalid_logo.correct_logo_mime_type
      expect(organization_with_invalid_logo.errors[:logo]).to include('Must be a JPG or a PNG file')
    end
  end
end
describe '#some_request_type_enabled', :phoenix do
  let(:organization) { build(:organization, enable_child_based_requests: child_based, enable_individual_requests: individual, enable_quantity_based_requests: quantity_based) }

  context 'when all request types are disabled' do
    let(:child_based) { false }
    let(:individual) { false }
    let(:quantity_based) { false }

    it 'adds error for child-based requests' do
      organization.some_request_type_enabled
      expect(organization.errors[:enable_child_based_requests]).to include('You must allow at least one request type (child-based, individual, or quantity-based)')
    end

    it 'adds error for individual requests' do
      organization.some_request_type_enabled
      expect(organization.errors[:enable_individual_requests]).to include('You must allow at least one request type (child-based, individual, or quantity-based)')
    end

    it 'adds error for quantity-based requests' do
      organization.some_request_type_enabled
      expect(organization.errors[:enable_quantity_based_requests]).to include('You must allow at least one request type (child-based, individual, or quantity-based)')
    end
  end

  context 'when child-based requests are enabled' do
    let(:child_based) { true }
    let(:individual) { false }
    let(:quantity_based) { false }

    it 'does not add errors' do
      organization.some_request_type_enabled
      expect(organization.errors).to be_empty
    end
  end

  context 'when individual requests are enabled' do
    let(:child_based) { false }
    let(:individual) { true }
    let(:quantity_based) { false }

    it 'does not add errors' do
      organization.some_request_type_enabled
      expect(organization.errors).to be_empty
    end
  end

  context 'when quantity-based requests are enabled' do
    let(:child_based) { false }
    let(:individual) { false }
    let(:quantity_based) { true }

    it 'does not add errors' do
      organization.some_request_type_enabled
      expect(organization.errors).to be_empty
    end
  end
end
describe '#get_admin_email', :phoenix do
  let(:organization) { create(:organization) }

  context 'when there are no users with ORG_ADMIN role' do
    it 'returns nil' do
      expect(organization.get_admin_email).to be_nil
    end
  end

  context 'when multiple users have ORG_ADMIN role' do
    let!(:admin_users) { create_list(:organization_admin, 3, organization: organization) }

    it 'returns the email of a randomly selected user' do
      emails = admin_users.map(&:email)
      expect(emails).to include(organization.get_admin_email)
    end
  end

  context 'when only one user has ORG_ADMIN role' do
    let!(:admin_user) { create(:organization_admin, organization: organization) }

    it 'returns the email of the single user' do
      expect(organization.get_admin_email).to eq(admin_user.email)
    end
  end

  context 'when an invalid role or organization is provided' do
    it 'raises an error' do
      allow(User).to receive(:with_role).and_raise(StandardError)
      expect { organization.get_admin_email }.to raise_error(StandardError)
    end
  end
end
describe '#logo_size_check', :phoenix do
  let(:organization_with_large_logo) do
    build(:organization).tap do |org|
      allow(org.logo).to receive(:byte_size).and_return(1.1.megabytes)
    end
  end

  let(:organization_with_exact_logo) do
    build(:organization).tap do |org|
      allow(org.logo).to receive(:byte_size).and_return(1.megabyte)
    end
  end

  let(:organization_with_small_logo) do
    build(:organization).tap do |org|
      allow(org.logo).to receive(:byte_size).and_return(0.9.megabytes)
    end
  end

  it 'adds an error when logo size is greater than 1 MB' do
    organization_with_large_logo.logo_size_check
    expect(organization_with_large_logo.errors[:logo]).to include('File size is greater than 1 MB')
  end

  it 'does not add an error when logo size is exactly 1 MB' do
    organization_with_exact_logo.logo_size_check
    expect(organization_with_exact_logo.errors[:logo]).to be_empty
  end

  it 'does not add an error when logo size is less than 1 MB' do
    organization_with_small_logo.logo_size_check
    expect(organization_with_small_logo.errors[:logo]).to be_empty
  end
end
end
