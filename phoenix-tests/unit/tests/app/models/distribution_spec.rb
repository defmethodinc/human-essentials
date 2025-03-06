
require "rails_helper"

RSpec.describe Distribution do
describe '#distributed_at', :phoenix do
  let(:distribution_midnight) { build(:distribution, issued_at: issued_at_midnight) }
  let(:distribution_not_midnight) { build(:distribution, issued_at: issued_at_not_midnight) }
  let(:issued_at_midnight) { Time.zone.now.midnight }
  let(:issued_at_not_midnight) { Time.zone.now.change(hour: 10, min: 0, sec: 0) }

  context 'when issued_at is midnight' do
    it 'returns the distribution date format' do
      expect(distribution_midnight.distributed_at).to eq(issued_at_midnight.to_fs(:distribution_date))
    end
  end

  context 'when issued_at is not midnight' do
    it 'returns the distribution date time format' do
      expect(distribution_not_midnight.distributed_at).to eq(issued_at_not_midnight.to_fs(:distribution_date_time))
    end
  end
end
describe '#combine_duplicates', :phoenix do
  let(:distribution) { build(:distribution) }

  context 'when there are no line items' do
    it 'does not change the line items size' do
      expect { distribution.combine_duplicates }.not_to change { distribution.line_items.size }
    end
  end

  context 'when there are line items with non-zero quantities' do
    let(:distribution) { build(:distribution, :with_items, item_quantity: 5) }

    it 'reduces the line items size by one' do
      expect { distribution.combine_duplicates }.to change { distribution.line_items.size }.by(-1)
    end
  end

  context 'when there are invalid line items' do
    let(:distribution) { build(:distribution, :with_items, item_quantity: -1) }

    it 'does not change the line items size' do
      expect { distribution.combine_duplicates }.not_to change { distribution.line_items.size }
    end
  end

  context 'when there are line items with zero quantities' do
    let(:distribution) { build(:distribution, :with_items, item_quantity: 0) }

    it 'does not change the line items size' do
      expect { distribution.combine_duplicates }.not_to change { distribution.line_items.size }
    end
  end

  context 'when there are line items with the same item_id' do
    let(:item) { create(:item) }
    let(:distribution) { build(:distribution, :with_items, item: item, item_quantity: 5) }

    before do
      distribution.line_items << build(:line_item, item: item, quantity: 5, itemizable: distribution)
    end

    it 'aggregates quantities for line items with the same item_id' do
      expect { distribution.combine_duplicates }.to change { distribution.line_items.first.quantity }.from(5).to(10)
    end
  end
end
describe '#copy_line_items', :phoenix do
  let(:distribution) { create(:distribution) }
  let(:donation) { create(:donation) }

  context 'when there are no line items' do
    it 'does not change the line items count' do
      expect { distribution.copy_line_items(donation.id) }.not_to change { distribution.line_items.count }
    end
  end

  context 'when there is a single line item' do
    let!(:line_item) { create(:line_item, :for_donation, itemizable: donation) }

    it 'increases the line items count by 1' do
      expect { distribution.copy_line_items(donation.id) }.to change { distribution.line_items.count }.by(1)
    end

    it 'copies the attributes of the line item' do
      distribution.copy_line_items(donation.id)
      copied_item = distribution.line_items.last
      expect(copied_item.attributes.except('id', 'created_at', 'updated_at')).to eq(line_item.attributes.except('id', 'created_at', 'updated_at'))
    end
  end

  context 'when there are multiple line items' do
    let!(:line_items) { create_list(:line_item, 3, :for_donation, itemizable: donation) }

    it 'increases the line items count by the number of line items' do
      expect { distribution.copy_line_items(donation.id) }.to change { distribution.line_items.count }.by(3)
    end

    it 'copies the attributes of each line item' do
      distribution.copy_line_items(donation.id)
      copied_items = distribution.line_items.order(:id).last(3)
      line_items.each_with_index do |line_item, index|
        expect(copied_items[index].attributes.except('id', 'created_at', 'updated_at')).to eq(line_item.attributes.except('id', 'created_at', 'updated_at'))
      end
    end
  end

  context 'when an error occurs during line item creation' do
    before do
      allow_any_instance_of(LineItem).to receive(:save).and_return(false)
    end

    it 'does not change the line items count' do
      expect { distribution.copy_line_items(donation.id) }.not_to change { distribution.line_items.count }
    end
  end
end
describe '#copy_from_donation', :phoenix do
  let(:organization) { create(:organization) }
  let(:storage_location) { create(:storage_location, organization: organization) }
  let(:donation) { create(:donation, :with_items, organization: organization, storage_location: storage_location) }
  let(:distribution) { create(:distribution, organization: organization) }

  context 'when donation_id is provided and storage_location_id is provided' do
    it 'copies line items from donation' do
      distribution.copy_from_donation(donation.id, storage_location.id)
      expect(distribution.line_items).to eq(donation.line_items)
    end

    it 'sets storage location to the provided storage_location_id' do
      distribution.copy_from_donation(donation.id, storage_location.id)
      expect(distribution.storage_location).to eq(storage_location)
    end
  end

  context 'when donation_id is provided and storage_location_id is not provided' do
    it 'copies line items from donation' do
      distribution.copy_from_donation(donation.id, nil)
      expect(distribution.line_items).to eq(donation.line_items)
    end

    it 'does not set storage location' do
      distribution.copy_from_donation(donation.id, nil)
      expect(distribution.storage_location).to be_nil
    end
  end

  context 'when donation_id is not provided and storage_location_id is provided' do
    it 'does not copy line items' do
      distribution.copy_from_donation(nil, storage_location.id)
      expect(distribution.line_items).to be_empty
    end

    it 'sets storage location to the provided storage_location_id' do
      distribution.copy_from_donation(nil, storage_location.id)
      expect(distribution.storage_location).to eq(storage_location)
    end
  end

  context 'when donation_id is not provided and storage_location_id is not provided' do
    it 'does not copy line items' do
      distribution.copy_from_donation(nil, nil)
      expect(distribution.line_items).to be_empty
    end

    it 'does not set storage location' do
      distribution.copy_from_donation(nil, nil)
      expect(distribution.storage_location).to be_nil
    end
  end
end
describe "#initialize_request_items", :phoenix do
  let(:organization) { create(:organization) }
  let(:storage_location) { create(:storage_location, :with_items, organization: organization) }
  let(:partner) { create(:partner) }
  let(:distribution) { build(:distribution, storage_location: storage_location, partner: partner, organization: organization) }

  it "returns immediately if request is nil" do
    distribution.request = nil
    distribution.initialize_request_items
    expect(distribution.line_items).to be_empty
  end

  context "when line_items is empty" do
    before do
      distribution.line_items = []
      distribution.request = build(:request, item_requests: [build(:item_request)])
      distribution.initialize_request_items
    end

    it "creates line_items from item_requests" do
      expect(distribution.line_items).not_to be_empty
    end
  end

  context "when request.item_requests is empty" do
    before do
      distribution.request = build(:request, item_requests: [])
      distribution.initialize_request_items
    end

    it "does not create new line_items" do
      expect(distribution.line_items).to be_empty
    end
  end

  context "when all line_items have corresponding item_requests" do
    let(:item_request) { build(:item_request) }

    before do
      distribution.line_items = [build(:line_item, item_id: item_request.item_id)]
      distribution.request = build(:request, item_requests: [item_request])
      distribution.initialize_request_items
    end

    it "assigns item_requests to line_items" do
      expect(distribution.line_items.first.requested_item).to eq(item_request)
    end
  end

  context "when some item_requests do not have corresponding line_items" do
    let(:item_request) { build(:item_request) }

    before do
      distribution.line_items = []
      distribution.request = build(:request, item_requests: [item_request])
      distribution.initialize_request_items
    end

    it "creates new line_items for those item_requests" do
      expect(distribution.line_items.first.requested_item).to eq(item_request)
    end
  end

  context "when some line_items do not have corresponding item_requests" do
    let(:item_request) { build(:item_request) }

    before do
      distribution.line_items = [build(:line_item, item_id: 999)]
      distribution.request = build(:request, item_requests: [item_request])
      distribution.initialize_request_items
    end

    it "includes item_requests in line_items" do
      expect(distribution.line_items.map(&:requested_item)).to include(item_request)
    end
  end
end
describe "#copy_from_request", :phoenix do
  let(:organization) { create(:organization, :with_items) }
  let(:partner) { create(:partner) }
  let(:partner_user) { create(:partner_user) }
  let(:distribution) { build(:distribution) }

  context "with a valid request" do
    let(:request) { create(:request, organization: organization, partner: partner, partner_user: partner_user) }

    it "sets the request attribute" do
      distribution.copy_from_request(request.id)
      expect(distribution.request).to eq(request)
    end

    it "sets the organization_id attribute" do
      distribution.copy_from_request(request.id)
      expect(distribution.organization_id).to eq(request.organization_id)
    end

    it "sets the partner_id attribute" do
      distribution.copy_from_request(request.id)
      expect(distribution.partner_id).to eq(request.partner_id)
    end

    it "sets the agency_rep attribute" do
      distribution.copy_from_request(request.id)
      expect(distribution.agency_rep).to eq(request.partner_user&.formatted_email)
    end

    it "sets the comment attribute" do
      distribution.copy_from_request(request.id)
      expect(distribution.comment).to eq(request.comments)
    end

    it "sets the issued_at attribute to tomorrow" do
      distribution.copy_from_request(request.id)
      expect(distribution.issued_at).to eq(Time.zone.today + 1.day)
    end
  end

  context "with a request with no item_requests" do
    let(:request) { create(:request, organization: organization, partner: partner, partner_user: partner_user, item_requests: []) }

    it "does not create any line_items" do
      distribution.copy_from_request(request.id)
      expect(distribution.line_items).to be_empty
    end
  end

  describe "when item_requests have a request_unit" do
    let(:item_request) { create(:item_request, item_id: 1, quantity: 10, request_unit: 'box') }
    let(:request) { create(:request, organization: organization, partner: partner, partner_user: partner_user, item_requests: [item_request]) }

    it "does not prefill quantity for line_items" do
      distribution.copy_from_request(request.id)
      line_item = distribution.line_items.find_by(item_id: item_request.item_id)
      expect(line_item.quantity).to be_nil
    end
  end

  describe "when item_requests do not have a request_unit" do
    let(:item_request) { create(:item_request, item_id: 1, quantity: 10) }
    let(:request) { create(:request, organization: organization, partner: partner, partner_user: partner_user, item_requests: [item_request]) }

    it "prefills quantity for line_items" do
      distribution.copy_from_request(request.id)
      line_item = distribution.line_items.find_by(item_id: item_request.item_id)
      expect(line_item.quantity).to eq(item_request.quantity)
    end
  end

  context "with a non-existent request (invalid request_id)" do
    it "raises an ActiveRecord::RecordNotFound error" do
      expect { distribution.copy_from_request(-1) }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
describe "#combine_distribution", :phoenix do
  let(:empty_line_items) { [] }
  let(:invalid_line_item) { build(:line_item, quantity: 1, item: build(:item, :inactive)) }
  let(:zero_quantity_line_item) { build(:line_item, quantity: 0) }
  let(:valid_line_item) { build(:line_item, quantity: 1, item: build(:item, :active)) }
  let(:duplicate_line_item_1) { build(:line_item, quantity: 1, item: build(:item, :active, name: "Duplicate")) }
  let(:duplicate_line_item_2) { build(:line_item, quantity: 2, item: build(:item, :active, name: "Duplicate")) }
  let(:mixed_line_items) { [valid_line_item, invalid_line_item, zero_quantity_line_item] }

  it "does nothing when line_items is empty" do
    distribution = Distribution.new(line_items: empty_line_items)
    expect { distribution.combine_distribution }.not_to change { distribution.line_items }
  end

  it "does nothing when line_items contains only invalid items" do
    distribution = Distribution.new(line_items: [invalid_line_item])
    expect { distribution.combine_distribution }.not_to change { distribution.line_items }
  end

  it "does nothing when line_items contains items with zero quantity" do
    distribution = Distribution.new(line_items: [zero_quantity_line_item])
    expect { distribution.combine_distribution }.not_to change { distribution.line_items }
  end

  describe "when line_items contains valid items" do
    it "combines line_items with valid items and non-zero quantity" do
      distribution = Distribution.new(line_items: [valid_line_item])
      expect { distribution.combine_distribution }.not_to change { distribution.line_items.size }
      expect(distribution.line_items.first.quantity).to eq(1)
    end
  end

  describe "when line_items contains duplicate items" do
    it "combines duplicate line_items with the same item_id" do
      distribution = Distribution.new(line_items: [duplicate_line_item_1, duplicate_line_item_2])
      expect { distribution.combine_distribution }.to change { distribution.line_items.size }.from(2).to(1)
    end

    it "updates the quantity of combined line_items" do
      distribution = Distribution.new(line_items: [duplicate_line_item_1, duplicate_line_item_2])
      distribution.combine_distribution
      expect(distribution.line_items.first.quantity).to eq(3)
    end
  end

  describe "when line_items contains a mix of valid and invalid items" do
    it "removes invalid and zero quantity items" do
      distribution = Distribution.new(line_items: mixed_line_items)
      expect { distribution.combine_distribution }.to change { distribution.line_items.size }.from(3).to(1)
    end

    it "keeps valid items with correct quantity" do
      distribution = Distribution.new(line_items: mixed_line_items)
      distribution.combine_distribution
      expect(distribution.line_items.first.quantity).to eq(1)
    end
  end
end
describe "#csv_export_attributes", :phoenix do
  let(:organization) { create(:organization) }
  let(:partner) { create(:partner, organization: organization) }
  let(:storage_location) { create(:storage_location, organization: organization) }
  let(:distribution) { build(:distribution, partner: partner, storage_location: storage_location, organization: organization, issued_at: issued_at, delivery_method: delivery_method, state: state, agency_rep: agency_rep) }
  let(:issued_at) { Time.current }
  let(:delivery_method) { :pick_up }
  let(:state) { :scheduled }
  let(:agency_rep) { "John Doe" }

  it "returns correct attributes when all values are present" do
    expect(distribution.csv_export_attributes).to eq([
      partner.name,
      issued_at.strftime("%F"),
      storage_location.name,
      distribution.total_quantity,
      distribution.cents_to_dollar(distribution.line_items.total_value),
      delivery_method,
      state,
      agency_rep
    ])
  end

  describe "when partner is missing" do
    let(:partner) { nil }

    it "handles missing partner name" do
      expect(distribution.csv_export_attributes.first).to be_nil
    end
  end

  describe "when issued_at is nil" do
    let(:issued_at) { nil }

    it "handles missing issued_at date" do
      expect(distribution.csv_export_attributes[1]).to be_nil
    end
  end

  describe "when storage_location is missing" do
    let(:storage_location) { nil }

    it "handles missing storage location name" do
      expect(distribution.csv_export_attributes[2]).to be_nil
    end
  end

  describe "when total_quantity is zero" do
    before do
      allow(distribution).to receive(:total_quantity).and_return(0)
    end

    it "handles zero total quantity" do
      expect(distribution.csv_export_attributes[3]).to eq(0)
    end
  end

  describe "when line_items total_value is zero" do
    before do
      allow(distribution.line_items).to receive(:total_value).and_return(0)
    end

    it "handles zero total value" do
      expect(distribution.csv_export_attributes[4]).to eq(distribution.cents_to_dollar(0))
    end
  end

  describe "when delivery_method is nil" do
    let(:delivery_method) { nil }

    it "handles missing delivery method" do
      expect(distribution.csv_export_attributes[5]).to be_nil
    end
  end

  describe "when state is nil" do
    let(:state) { nil }

    it "handles missing state" do
      expect(distribution.csv_export_attributes[6]).to be_nil
    end
  end

  describe "when agency_rep is nil" do
    let(:agency_rep) { nil }

    it "handles missing agency representative" do
      expect(distribution.csv_export_attributes[7]).to be_nil
    end
  end
end
describe '#future?', :phoenix do
  let(:future_distribution) { build(:distribution, issued_at: Time.zone.today + 1.day) }
  let(:today_distribution) { build(:distribution, issued_at: Time.zone.today) }
  let(:past_distribution) { build(:distribution, issued_at: Time.zone.today - 1.day) }

  it 'returns true when issued_at is in the future' do
    expect(future_distribution.future?).to eq(true)
  end

  it 'returns false when issued_at is today' do
    expect(today_distribution.future?).to eq(false)
  end

  it 'returns false when issued_at is in the past' do
    expect(past_distribution.future?).to eq(false)
  end
end
describe '#past?', :phoenix do
  let(:distribution_past) { build(:distribution, :past) }
  let(:distribution_today) { build(:distribution, issued_at: Time.zone.today) }
  let(:distribution_future) { build(:distribution, issued_at: Time.zone.tomorrow) }

  it 'returns true if issued_at is before today' do
    expect(distribution_past.past?).to be true
  end

  it 'returns false if issued_at is today' do
    expect(distribution_today.past?).to be false
  end

  it 'returns false if issued_at is after today' do
    expect(distribution_future.past?).to be false
  end
end
describe '#line_items_quantity_is_positive', :phoenix do
  let(:distribution_with_nil_storage) { build(:distribution, storage_location: nil) }
  let(:distribution_with_nil_quantity) { build(:distribution, :with_items, item_quantity: nil) }
  let(:distribution_with_low_quantity) { build(:distribution, :with_items, item_quantity: 0) }
  let(:distribution_with_valid_quantity) { build(:distribution, :with_items, item_quantity: 1) }

  it 'does nothing if storage_location is nil' do
    distribution_with_nil_storage.line_items_quantity_is_positive
    expect(distribution_with_nil_storage.errors[:base]).to be_empty
  end

  context 'when line item quantity is nil' do
    it 'adds an error for line item with nil quantity' do
      distribution_with_nil_quantity.line_items_quantity_is_positive
      expect(distribution_with_nil_quantity.errors[:line_items]).to include('quantity must be at least 1')
    end
  end

  context 'when line item quantity is less than 1' do
    it 'adds an error for line item with quantity less than 1' do
      distribution_with_low_quantity.line_items_quantity_is_positive
      expect(distribution_with_low_quantity.errors[:line_items]).to include('quantity must be at least 1')
    end
  end

  context 'when line item quantity is 1 or more' do
    it 'does not add an error for line item with quantity 1 or more' do
      distribution_with_valid_quantity.line_items_quantity_is_positive
      expect(distribution_with_valid_quantity.errors[:line_items]).to be_empty
    end
  end
end
describe "#reset_shipping_cost", :phoenix do
  let(:distribution_shipped) { build(:distribution, delivery_method: 'shipped', shipping_cost: 10.0) }
  let(:distribution_not_shipped) { build(:distribution, delivery_method: 'pick_up', shipping_cost: 10.0) }

  it "does not reset shipping_cost when delivery_method is 'shipped'" do
    distribution_shipped.reset_shipping_cost
    expect(distribution_shipped.shipping_cost).to eq(10.0)
  end

  describe "when delivery_method is not 'shipped'" do
    it "resets shipping_cost to nil" do
      distribution_not_shipped.reset_shipping_cost
      expect(distribution_not_shipped.shipping_cost).to be_nil
    end
  end
end
end
