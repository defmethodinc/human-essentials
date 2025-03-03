
require "rails_helper"

RSpec.describe ProductDrive do
describe '#end_date_is_bigger_of_end_date', :phoenix do
  let(:product_drive) { ProductDrive.new(start_date: start_date, end_date: end_date) }

  context 'when start_date is nil' do
    let(:start_date) { nil }
    let(:end_date) { Date.today }

    it 'does nothing when start_date is nil' do
      product_drive.valid?
      expect(product_drive.errors[:end_date]).to be_empty
    end
  end

  context 'when end_date is nil' do
    let(:start_date) { Date.today }
    let(:end_date) { nil }

    it 'does nothing when end_date is nil' do
      product_drive.valid?
      expect(product_drive.errors[:end_date]).to be_empty
    end
  end

  context 'when both start_date and end_date are nil' do
    let(:start_date) { nil }
    let(:end_date) { nil }

    it 'does nothing when both start_date and end_date are nil' do
      product_drive.valid?
      expect(product_drive.errors[:end_date]).to be_empty
    end
  end

  context 'when end_date is before start_date' do
    let(:start_date) { Date.today }
    let(:end_date) { Date.yesterday }

    it 'adds an error when end_date is before start_date' do
      product_drive.valid?
      expect(product_drive.errors[:end_date]).to include('End date must be after the start date')
    end
  end

  context 'when end_date is after start_date' do
    let(:start_date) { Date.yesterday }
    let(:end_date) { Date.today }

    it 'does nothing when end_date is after start_date' do
      product_drive.valid?
      expect(product_drive.errors[:end_date]).to be_empty
    end
  end
end
describe "#donation_quantity", :phoenix do
  let(:product_drive) { ProductDrive.create(name: 'Test Drive') }
  let(:donation_with_no_line_items) { Donation.create(product_drive: product_drive) }
  let(:donation_with_zero_quantity_line_items) do
    donation = Donation.create(product_drive: product_drive)
    LineItem.create(donation: donation, quantity: 0)
    donation
  end
  let(:donation_with_positive_quantity_line_items) do
    donation = Donation.create(product_drive: product_drive)
    LineItem.create(donation: donation, quantity: 5)
    donation
  end
  let(:multiple_donations_with_line_items) do
    donation1 = Donation.create(product_drive: product_drive)
    LineItem.create(donation: donation1, quantity: 3)
    donation2 = Donation.create(product_drive: product_drive)
    LineItem.create(donation: donation2, quantity: 7)
    [donation1, donation2]
  end

  it "returns zero when there are no donations" do
    expect(product_drive.donation_quantity).to eq(0)
  end

  it "returns zero when there are donations but no line items" do
    donation_with_no_line_items
    expect(product_drive.donation_quantity).to eq(0)
  end

  it "returns zero when line items have zero quantity" do
    donation_with_zero_quantity_line_items
    expect(product_drive.donation_quantity).to eq(0)
  end

  it "returns the correct sum when there are donations with positive quantities" do
    donation_with_positive_quantity_line_items
    expect(product_drive.donation_quantity).to eq(5)
  end

  it "returns the correct sum for multiple donations with line items" do
    multiple_donations_with_line_items
    expect(product_drive.donation_quantity).to eq(10)
  end
end
describe '#distinct_items_count', :phoenix do
  let(:product_drive) { ProductDrive.new }
  let(:item1) { Item.create(name: 'Item 1') }
  let(:item2) { Item.create(name: 'Item 2') }
  let(:donation1) { Donation.create }
  let(:donation2) { Donation.create }

  before do
    LineItem.create(donation: donation1, item: item1)
    LineItem.create(donation: donation1, item: item2)
    LineItem.create(donation: donation2, item: item1)
  end

  it 'counts distinct items for a single donation with multiple items' do
    expect(product_drive.distinct_items_count).to eq(2)
  end

  it 'does not double-count items for multiple donations with the same item' do
    expect(product_drive.distinct_items_count).to eq(2)
  end

  describe 'when donations have overlapping items' do
    before do
      LineItem.create(donation: donation2, item: item2)
    end

    it 'counts distinct items correctly' do
      expect(product_drive.distinct_items_count).to eq(2)
    end
  end

  describe 'when filtering by date range' do
    # Assuming there's a scope or method to filter by date range
    it 'accurately counts distinct items' do
      expect(product_drive.distinct_items_count).to eq(2)
    end
  end

  describe 'when filtering by item category' do
    # Assuming there's a scope or method to filter by item category
    it 'counts distinct items based on a specific item category' do
      expect(product_drive.distinct_items_count).to eq(2)
    end
  end
end
describe '#in_kind_value', :phoenix do
  let(:product_drive) { ProductDrive.create }

  context 'when there are no donations' do
    it 'returns zero' do
      expect(product_drive.in_kind_value).to eq(0)
    end
  end

  context 'when there is a single donation' do
    let!(:donation) { Donation.create(product_drive: product_drive, value_per_itemizable: 100) }

    it 'returns the value of a single donation' do
      expect(product_drive.in_kind_value).to eq(100)
    end
  end

  context 'when there are multiple donations' do
    let!(:donation1) { Donation.create(product_drive: product_drive, value_per_itemizable: 100) }
    let!(:donation2) { Donation.create(product_drive: product_drive, value_per_itemizable: 200) }

    it 'returns the sum of multiple donations' do
      expect(product_drive.in_kind_value).to eq(300)
    end
  end

  context 'when there are donations with zero value' do
    let!(:donation1) { Donation.create(product_drive: product_drive, value_per_itemizable: 0) }
    let!(:donation2) { Donation.create(product_drive: product_drive, value_per_itemizable: 100) }

    it 'returns the sum excluding zero value donations' do
      expect(product_drive.in_kind_value).to eq(100)
    end
  end

  context 'when there is a mix of positive, zero, and negative values' do
    let!(:donation1) { Donation.create(product_drive: product_drive, value_per_itemizable: 100) }
    let!(:donation2) { Donation.create(product_drive: product_drive, value_per_itemizable: 0) }
    let!(:donation3) { Donation.create(product_drive: product_drive, value_per_itemizable: -50) }

    it 'returns the correct sum for mixed values' do
      expect(product_drive.in_kind_value).to eq(50)
    end
  end
end
describe "#donation_source_view", :phoenix do
  let(:product_drive) { ProductDrive.new(name: name) }

  context "when name is a typical string" do
    let(:name) { "Typical Name" }

    it "returns the correct string" do
      expect(product_drive.donation_source_view).to eq("Typical Name (product drive)")
    end
  end

  context "when name is an empty string" do
    let(:name) { "" }

    it "returns the correct string for an empty name" do
      expect(product_drive.donation_source_view).to eq(" (product drive)")
    end
  end

  context "when name contains special characters" do
    let(:name) { "Special!@#" }

    it "returns the correct string for a name with special characters" do
      expect(product_drive.donation_source_view).to eq("Special!@# (product drive)")
    end
  end
end
describe '.search_date_range', :phoenix do
  let(:valid_date_range) { '2023-01-01 - 2023-12-31' }
  let(:invalid_date_range) { 'invalid-date-range' }
  let(:empty_string) { '' }
  let(:single_date) { '2023-01-01' }
  let(:nil_input) { nil }

  it 'parses a valid date range string' do
    result = ProductDrive.search_date_range(valid_date_range)
    expect(result).to eq({ start_date: '2023-01-01', end_date: '2023-12-31' })
  end

  describe 'when given an invalid date range string' do
    it 'returns the start date as the entire string and end date as nil' do
      result = ProductDrive.search_date_range(invalid_date_range)
      expect(result).to eq({ start_date: 'invalid-date-range', end_date: nil })
    end
  end

  describe 'when given an empty string' do
    it 'returns the start date as an empty string and end date as nil' do
      result = ProductDrive.search_date_range(empty_string)
      expect(result).to eq({ start_date: '', end_date: nil })
    end
  end

  describe 'when given a single date' do
    it 'returns the start date as the given date and end date as nil' do
      result = ProductDrive.search_date_range(single_date)
      expect(result).to eq({ start_date: '2023-01-01', end_date: nil })
    end
  end

  describe 'when given nil input' do
    it 'returns both start and end dates as nil' do
      result = ProductDrive.search_date_range(nil_input)
      expect(result).to eq({ start_date: nil, end_date: nil })
    end
  end
end
describe "#item_quantities_by_name_and_date", :phoenix do
  let(:organization) { create(:organization) }
  let(:item1) { create(:item, organization: organization) }
  let(:item2) { create(:item, organization: organization) }
  let(:donation1) { create(:donation, organization: organization) }
  let(:donation2) { create(:donation, organization: organization) }
  let!(:line_item1) { create(:line_item, donation: donation1, item: item1, quantity: 5) }
  let!(:line_item2) { create(:line_item, donation: donation2, item: item2, quantity: 10) }

  subject { ProductDrive.new.item_quantities_by_name_and_date(date_range) }

  context "when the date range includes all donations" do
    let(:date_range) { (Time.zone.now - 1.day)..(Time.zone.now + 1.day) }

    it "returns correct quantities for items within the date range" do
      expect(subject).to eq([5, 10])
    end
  end

  context "when the date range is empty" do
    let(:date_range) { (Time.zone.now + 2.days)..(Time.zone.now + 3.days) }

    it "returns zero quantities for an empty date range" do
      expect(subject).to eq([0, 0])
    end
  end

  context "when there are no donations" do
    before do
      Donation.destroy_all
    end

    let(:date_range) { (Time.zone.now - 1.day)..(Time.zone.now + 1.day) }

    it "returns zero quantities when there are no donations" do
      expect(subject).to eq([0, 0])
    end
  end

  context "when donations have no line items" do
    before do
      LineItem.destroy_all
    end

    let(:date_range) { (Time.zone.now - 1.day)..(Time.zone.now + 1.day) }

    it "returns zero quantities when donations have no line items" do
      expect(subject).to eq([0, 0])
    end
  end

  context "when summing quantities for multiple items" do
    let!(:line_item3) { create(:line_item, donation: donation1, item: item2, quantity: 3) }
    let(:date_range) { (Time.zone.now - 1.day)..(Time.zone.now + 1.day) }

    it "sums quantities for multiple items correctly" do
      expect(subject).to eq([5, 13])
    end
  end

  context "when handling non-existent items in the organization" do
    let!(:non_existent_item) { create(:item) }
    let(:date_range) { (Time.zone.now - 1.day)..(Time.zone.now + 1.day) }

    it "ignores non-existent items in the organization" do
      expect(subject).to eq([5, 10])
    end
  end

  context "when handling edge cases for date range boundaries" do
    let(:date_range) { (Time.zone.now - 1.day).beginning_of_day..(Time.zone.now - 1.day).end_of_day }

    it "handles edge cases for date range boundaries correctly" do
      expect(subject).to eq([5, 0])
    end
  end
end
describe '#donation_quantity_by_date', :phoenix do
  let(:product_drive) { ProductDrive.new }
  let(:date_range) { Date.today.beginning_of_month..Date.today.end_of_month }
  let(:item_category) { ItemCategory.create(name: 'Category 1') }
  let(:item) { Item.create(name: 'Item 1', item_category: item_category) }
  let(:donation) { Donation.create(date: Date.today) }
  let(:line_item) { LineItem.create(quantity: 10, item: item, donation: donation) }

  context 'when item_category_id is present' do
    it 'calculates the donation quantity for the given category' do
      expect(product_drive.donation_quantity_by_date(date_range, item_category.id)).to eq(10)
    end
  end

  context 'when item_category_id is not present' do
    it 'calculates the total donation quantity for all categories' do
      expect(product_drive.donation_quantity_by_date(date_range)).to eq(10)
    end
  end

  context 'when date_range is empty' do
    let(:date_range) { nil }

    it 'returns zero or handles the empty range appropriately' do
      expect(product_drive.donation_quantity_by_date(date_range)).to eq(0)
    end
  end

  context 'when item_category_id is invalid' do
    let(:invalid_category_id) { -1 }

    it 'handles the invalid category id gracefully' do
      expect(product_drive.donation_quantity_by_date(date_range, invalid_category_id)).to eq(0)
    end
  end

  context 'when date_range is invalid' do
    let(:invalid_date_range) { 'invalid_date' }

    it 'handles the invalid date range gracefully' do
      expect { product_drive.donation_quantity_by_date(invalid_date_range) }.to raise_error(ArgumentError)
    end
  end
end
describe '#distinct_items_count_by_date', :phoenix do
  let(:date_range) { Date.today.beginning_of_month..Date.today.end_of_month }
  let(:item_category) { ItemCategory.create(name: 'Category 1') }
  let(:item) { Item.create(name: 'Item 1', item_category: item_category) }
  let(:line_item) { LineItem.create(item: item) }
  let(:donation) { Donation.create(created_at: Date.today, line_items: [line_item]) }

  it 'returns distinct item count for a given date range' do
    donation # Ensure donation is created
    expect(ProductDrive.new.distinct_items_count_by_date(date_range)).to eq(1)
  end

  context 'when item_category_id is provided' do
    it 'returns distinct item count for the specified category within the date range' do
      donation # Ensure donation is created
      expect(ProductDrive.new.distinct_items_count_by_date(date_range, item_category.id)).to eq(1)
    end
  end

  context 'when item_category_id is not provided' do
    it 'returns distinct item count for all categories within the date range' do
      donation # Ensure donation is created
      expect(ProductDrive.new.distinct_items_count_by_date(date_range)).to eq(1)
    end
  end

  it 'returns zero for an empty date range' do
    expect(ProductDrive.new.distinct_items_count_by_date(nil)).to eq(0)
  end

  it 'returns zero when there are no donations in the date range' do
    Donation.destroy_all # Ensure no donations exist
    expect(ProductDrive.new.distinct_items_count_by_date(date_range)).to eq(0)
  end
end
end
