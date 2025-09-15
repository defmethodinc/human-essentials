
require "rails_helper"

RSpec.describe ProductDrive do
describe '#end_date_is_bigger_of_end_date', :phoenix do
  let(:product_drive) { ProductDrive.new(start_date: start_date, end_date: end_date) }

  context 'when both start_date and end_date are nil' do
    let(:start_date) { nil }
    let(:end_date) { nil }

    it 'does not add errors to end_date' do
      product_drive.valid?
      expect(product_drive.errors[:end_date]).to be_empty
    end
  end

  context 'when start_date is nil and end_date is not nil' do
    let(:start_date) { nil }
    let(:end_date) { Date.today }

    it 'does not add errors to end_date' do
      product_drive.valid?
      expect(product_drive.errors[:end_date]).to be_empty
    end
  end

  context 'when end_date is nil and start_date is not nil' do
    let(:start_date) { Date.today }
    let(:end_date) { nil }

    it 'does not add errors to end_date' do
      product_drive.valid?
      expect(product_drive.errors[:end_date]).to be_empty
    end
  end

  context 'when end_date is greater than start_date' do
    let(:start_date) { Date.today }
    let(:end_date) { Date.tomorrow }

    it 'does not add errors to end_date' do
      product_drive.valid?
      expect(product_drive.errors[:end_date]).to be_empty
    end
  end

  context 'when end_date is less than start_date' do
    let(:start_date) { Date.tomorrow }
    let(:end_date) { Date.today }

    it 'adds an error to end_date' do
      product_drive.valid?
      expect(product_drive.errors[:end_date]).to include('End date must be after the start date')
    end
  end
end
describe '#donation_quantity', :phoenix do
  let(:product_drive) { ProductDrive.create(name: 'Test Drive') }

  it 'returns 0 when there are no donations' do
    expect(product_drive.donation_quantity).to eq(0)
  end

  context 'when there are donations but no line items' do
    let!(:donation) { Donation.create(product_drive: product_drive) }

    it 'returns 0' do
      expect(product_drive.donation_quantity).to eq(0)
    end
  end

  context 'when line items have zero quantity' do
    let!(:donation) { Donation.create(product_drive: product_drive) }
    let!(:line_item) { LineItem.create(donation: donation, quantity: 0) }

    it 'returns 0' do
      expect(product_drive.donation_quantity).to eq(0)
    end
  end

  context 'when donations have positive quantities' do
    let!(:donation) { Donation.create(product_drive: product_drive) }
    let!(:line_item) { LineItem.create(donation: donation, quantity: 5) }

    it 'calculates the total quantity' do
      expect(product_drive.donation_quantity).to eq(5)
    end
  end

  context 'with multiple donations and line items' do
    let!(:donation1) { Donation.create(product_drive: product_drive) }
    let!(:donation2) { Donation.create(product_drive: product_drive) }
    let!(:line_item1) { LineItem.create(donation: donation1, quantity: 3) }
    let!(:line_item2) { LineItem.create(donation: donation2, quantity: 7) }

    it 'calculates the total quantity' do
      expect(product_drive.donation_quantity).to eq(10)
    end
  end
end
describe "#distinct_items_count", :phoenix do
  let(:product_drive) { ProductDrive.create(name: 'Test Drive') }

  it "returns 0 when there are no donations" do
    expect(product_drive.distinct_items_count).to eq(0)
  end

  context "when there are donations but no line items" do
    before do
      Donation.create(product_drive: product_drive)
    end

    it "returns 0" do
      expect(product_drive.distinct_items_count).to eq(0)
    end
  end

  context "when all line items have unique item_ids" do
    before do
      donation = Donation.create(product_drive: product_drive)
      LineItem.create(donation: donation, item_id: 1)
      LineItem.create(donation: donation, item_id: 2)
    end

    it "returns the correct count" do
      expect(product_drive.distinct_items_count).to eq(2)
    end
  end

  context "when some line items have duplicate item_ids" do
    before do
      donation = Donation.create(product_drive: product_drive)
      LineItem.create(donation: donation, item_id: 1)
      LineItem.create(donation: donation, item_id: 1)
      LineItem.create(donation: donation, item_id: 2)
    end

    it "returns the correct count" do
      expect(product_drive.distinct_items_count).to eq(2)
    end
  end

  context "when there are multiple donations with overlapping line items" do
    before do
      donation1 = Donation.create(product_drive: product_drive)
      donation2 = Donation.create(product_drive: product_drive)
      LineItem.create(donation: donation1, item_id: 1)
      LineItem.create(donation: donation2, item_id: 1)
      LineItem.create(donation: donation2, item_id: 2)
    end

    it "returns the correct count" do
      expect(product_drive.distinct_items_count).to eq(2)
    end
  end
end
describe '#in_kind_value', :phoenix do
  let(:product_drive) { ProductDrive.new }

  context 'when there are no donations' do
    it 'returns 0' do
      expect(product_drive.in_kind_value).to eq(0)
    end
  end

  context 'when there is a single donation' do
    let!(:donation) { Donation.create(value_per_itemizable: 100) }

    it 'returns the value of a single donation' do
      allow(product_drive).to receive(:donations).and_return([donation])
      expect(product_drive.in_kind_value).to eq(100)
    end
  end

  context 'when there are multiple donations' do
    let!(:donation1) { Donation.create(value_per_itemizable: 100) }
    let!(:donation2) { Donation.create(value_per_itemizable: 200) }

    it 'returns the sum of values for multiple donations' do
      allow(product_drive).to receive(:donations).and_return([donation1, donation2])
      expect(product_drive.in_kind_value).to eq(300)
    end
  end

  context 'when donations have nil value_per_itemizable' do
    let!(:donation) { Donation.create(value_per_itemizable: nil) }

    it 'handles donations with nil value_per_itemizable' do
      allow(product_drive).to receive(:donations).and_return([donation])
      expect(product_drive.in_kind_value).to eq(0)
    end
  end

  context 'when donations have zero value_per_itemizable' do
    let!(:donation) { Donation.create(value_per_itemizable: 0) }

    it 'handles donations with zero value_per_itemizable' do
      allow(product_drive).to receive(:donations).and_return([donation])
      expect(product_drive.in_kind_value).to eq(0)
    end
  end

  context 'when donations have negative value_per_itemizable' do
    let!(:donation) { Donation.create(value_per_itemizable: -50) }

    it 'handles donations with negative value_per_itemizable' do
      allow(product_drive).to receive(:donations).and_return([donation])
      expect(product_drive.in_kind_value).to eq(-50)
    end
  end
end
describe '#donation_source_view', :phoenix do
  let(:product_drive) { ProductDrive.new(name: name) }

  context 'with a typical name' do
    let(:name) { 'Typical Name' }

    it 'returns the correct string for a typical name' do
      expect(product_drive.donation_source_view).to eq('Typical Name (product drive)')
    end
  end

  context 'with an empty name' do
    let(:name) { '' }

    it 'handles an empty name' do
      expect(product_drive.donation_source_view).to eq(' (product drive)')
    end
  end

  context 'with a nil name' do
    let(:name) { nil }

    it 'handles a nil name' do
      expect(product_drive.donation_source_view).to eq(' (product drive)')
    end
  end

  context 'with special characters in the name' do
    let(:name) { '!@#$%^&*()' }

    it 'handles special characters in the name' do
      expect(product_drive.donation_source_view).to eq('!@#$%^&*() (product drive)')
    end
  end

  context 'with a long name' do
    let(:name) { 'a' * 256 }

    it 'handles a long name' do
      expect(product_drive.donation_source_view).to eq('#{'a' * 256} (product drive)')
    end
  end
end
describe '.search_date_range', :phoenix do
  let(:valid_dates) { '2023-01-01 - 2023-12-31' }
  let(:invalid_dates) { '2023/01/01 to 2023/12/31' }
  let(:empty_dates) { '' }
  let(:nil_dates) { nil }

  it 'returns correct hash for valid input' do
    result = ProductDrive.search_date_range(valid_dates)
    expect(result).to eq({ start_date: '2023-01-01', end_date: '2023-12-31' })
  end

  it 'raises NoMethodError for invalid input format' do
    expect { ProductDrive.search_date_range(invalid_dates) }.to raise_error(NoMethodError)
  end

  it 'returns empty hash for empty input' do
    result = ProductDrive.search_date_range(empty_dates)
    expect(result).to eq({ start_date: '', end_date: '' })
  end

  it 'raises NoMethodError for nil input' do
    expect { ProductDrive.search_date_range(nil_dates) }.to raise_error(NoMethodError)
  end
end
describe "#item_quantities_by_name_and_date", :phoenix do
  let(:organization) { Organization.create(name: 'Test Organization') }
  let(:item1) { Item.create(name: 'Item 1', organization: organization) }
  let(:item2) { Item.create(name: 'Item 2', organization: organization) }
  let(:date_range) { (Date.today - 7.days)..Date.today }

  let(:donation1) { Donation.create(date: Date.today - 5.days, organization: organization) }
  let(:donation2) { Donation.create(date: Date.today - 3.days, organization: organization) }

  let!(:line_item1) { LineItem.create(item: item1, donation: donation1, quantity: 10) }
  let!(:line_item2) { LineItem.create(item: item2, donation: donation2, quantity: 5) }

  subject { ProductDrive.new.item_quantities_by_name_and_date(date_range) }

  it "returns correct quantities for items within the date range" do
    expect(subject).to eq([10, 5])
  end

  context "when there are no donations in the given date range" do
    let(:date_range) { (Date.today - 14.days)..(Date.today - 8.days) }

    it "returns zero for all items" do
      expect(subject).to eq([0, 0])
    end
  end

  context "when items have no donations" do
    let(:donation1) { Donation.create(date: Date.today - 10.days, organization: organization) }
    let(:donation2) { Donation.create(date: Date.today - 9.days, organization: organization) }

    it "returns zero for items with no donations" do
      expect(subject).to eq([0, 0])
    end
  end

  context "when handling multiple items" do
    it "returns correct quantities for each item" do
      expect(subject).to eq([10, 5])
    end
  end

  context "when handling edge cases like overlapping date ranges or boundary dates" do
    let(:date_range) { (Date.today - 5.days)..(Date.today - 3.days) }

    it "returns correct quantities for overlapping date ranges" do
      expect(subject).to eq([10, 5])
    end
  end
end
describe "#donation_quantity_by_date", :phoenix do
  let(:date_range) { Date.today.beginning_of_month..Date.today.end_of_month }
  let(:item_category) { ItemCategory.create(name: "Category 1") }
  let(:item) { Item.create(name: "Item 1", item_category: item_category) }
  let(:line_item) { LineItem.create(item: item, quantity: 10) }
  let(:donation) { Donation.create(date: Date.today, line_items: [line_item]) }

  it "returns the correct sum of quantities for donations within a given date range" do
    donation
    expect(ProductDrive.new.donation_quantity_by_date(date_range)).to eq(10)
  end

  context "when item_category_id is provided" do
    it "filters donations by item_category_id and returns the correct sum" do
      donation
      expect(ProductDrive.new.donation_quantity_by_date(date_range, item_category.id)).to eq(10)
    end
  end

  context "when item_category_id is not provided" do
    it "returns the correct sum without filtering by item_category_id" do
      donation
      expect(ProductDrive.new.donation_quantity_by_date(date_range)).to eq(10)
    end
  end

  context "when the date range is empty" do
    let(:date_range) { Date.today..Date.today }

    it "returns zero for an empty date range" do
      expect(ProductDrive.new.donation_quantity_by_date(date_range)).to eq(0)
    end
  end

  context "when the date range is invalid" do
    let(:date_range) { Date.today..Date.yesterday }

    it "returns zero for an invalid date range" do
      expect(ProductDrive.new.donation_quantity_by_date(date_range)).to eq(0)
    end
  end

  context "when there are no donations in the given date range" do
    let(:date_range) { Date.today.next_month.beginning_of_month..Date.today.next_month.end_of_month }

    it "returns zero when there are no donations" do
      expect(ProductDrive.new.donation_quantity_by_date(date_range)).to eq(0)
    end
  end

  context "when the date range is a single day" do
    let(:date_range) { Date.today..Date.today }

    it "returns the correct sum for a single day range" do
      donation
      expect(ProductDrive.new.donation_quantity_by_date(date_range)).to eq(10)
    end
  end

  context "when date ranges overlap" do
    let(:date_range) { (Date.today - 1)..(Date.today + 1) }

    it "returns the correct sum for overlapping date ranges" do
      donation
      expect(ProductDrive.new.donation_quantity_by_date(date_range)).to eq(10)
    end
  end
end
describe "#distinct_items_count_by_date", :phoenix do
  let(:product_drive) { ProductDrive.new }
  let(:donation) { Donation.create!(date: Date.today) }
  let(:line_item) { LineItem.create!(donation: donation, item: item) }
  let(:item) { Item.create!(item_category_id: item_category_id) }
  let(:item_category_id) { nil }
  let(:date_range) { Date.today..Date.today }

  before do
    line_item
  end

  it "returns distinct item count when item_category_id is not provided" do
    expect(product_drive.distinct_items_count_by_date(date_range)).to eq(1)
  end

  describe "when item_category_id is provided" do
    let(:item_category_id) { 1 }

    it "returns distinct item count for the specific item_category_id" do
      expect(product_drive.distinct_items_count_by_date(date_range, item_category_id)).to eq(1)
    end
  end

  it "returns zero when date_range is nil" do
    expect(product_drive.distinct_items_count_by_date(nil)).to eq(0)
  end

  it "returns zero when date_range is empty" do
    empty_date_range = Date.today.next_day..Date.today
    expect(product_drive.distinct_items_count_by_date(empty_date_range)).to eq(0)
  end
end
end
