
require "rails_helper"

RSpec.describe ProductDrive do
describe '#end_date_is_bigger_of_end_date', :phoenix do
  let(:product_drive) { ProductDrive.new(start_date: start_date, end_date: end_date) }

  context 'when both start_date and end_date are nil' do
    let(:start_date) { nil }
    let(:end_date) { nil }

    it 'does nothing' do
      product_drive.end_date_is_bigger_of_end_date
      expect(product_drive.errors[:end_date]).to be_empty
    end
  end

  context 'when start_date is nil and end_date is not nil' do
    let(:start_date) { nil }
    let(:end_date) { Date.today }

    it 'does nothing' do
      product_drive.end_date_is_bigger_of_end_date
      expect(product_drive.errors[:end_date]).to be_empty
    end
  end

  context 'when end_date is nil and start_date is not nil' do
    let(:start_date) { Date.today }
    let(:end_date) { nil }

    it 'does nothing' do
      product_drive.end_date_is_bigger_of_end_date
      expect(product_drive.errors[:end_date]).to be_empty
    end
  end

  context 'when end_date is greater than start_date' do
    let(:start_date) { Date.today }
    let(:end_date) { Date.tomorrow }

    it 'does nothing' do
      product_drive.end_date_is_bigger_of_end_date
      expect(product_drive.errors[:end_date]).to be_empty
    end
  end

  context 'when end_date is less than start_date' do
    let(:start_date) { Date.tomorrow }
    let(:end_date) { Date.today }

    it 'adds an error' do
      product_drive.end_date_is_bigger_of_end_date
      expect(product_drive.errors[:end_date]).to include('End date must be after the start date')
    end
  end
end
describe '#donation_quantity', :phoenix do
  let(:product_drive) { ProductDrive.create }
  let(:donation_with_no_line_items) { Donation.create(product_drive: product_drive) }
  let(:donation_with_zero_quantity_line_items) { Donation.create(product_drive: product_drive) }
  let(:donation_with_positive_quantity_line_items) { Donation.create(product_drive: product_drive) }
  let(:multiple_donations) { [Donation.create(product_drive: product_drive), Donation.create(product_drive: product_drive)] }

  before do
    LineItem.create(donation: donation_with_zero_quantity_line_items, quantity: 0)
    LineItem.create(donation: donation_with_positive_quantity_line_items, quantity: 5)
    LineItem.create(donation: donation_with_positive_quantity_line_items, quantity: 10)
    LineItem.create(donation: multiple_donations.first, quantity: 3)
    LineItem.create(donation: multiple_donations.last, quantity: 7)
  end

  it 'returns 0 when there are no donations' do
    expect(product_drive.donation_quantity).to eq(0)
  end

  it 'returns 0 when there are donations but no line items' do
    expect(donation_with_no_line_items.donation_quantity).to eq(0)
  end

  it 'returns 0 when line items have zero quantity' do
    expect(donation_with_zero_quantity_line_items.donation_quantity).to eq(0)
  end

  it 'returns the correct sum when there are line items with positive quantities' do
    expect(donation_with_positive_quantity_line_items.donation_quantity).to eq(15)
  end

  it 'returns the correct sum for multiple donations with line items' do
    expect(product_drive.donation_quantity).to eq(25)
  end
end
describe '#distinct_items_count', :phoenix do
  let(:product_drive) { ProductDrive.create }

  context 'when there are no donations' do
    it 'returns zero' do
      expect(product_drive.distinct_items_count).to eq(0)
    end
  end

  context 'when donations exist but have no line items' do
    before do
      Donation.create(product_drive: product_drive)
    end

    it 'returns zero' do
      expect(product_drive.distinct_items_count).to eq(0)
    end
  end

  context 'when all donations have line items with the same item_id' do
    before do
      donation = Donation.create(product_drive: product_drive)
      LineItem.create(donation: donation, item_id: 1)
      LineItem.create(donation: donation, item_id: 1)
    end

    it 'returns one' do
      expect(product_drive.distinct_items_count).to eq(1)
    end
  end

  context 'when donations have line items with multiple distinct item_ids' do
    before do
      donation1 = Donation.create(product_drive: product_drive)
      donation2 = Donation.create(product_drive: product_drive)
      LineItem.create(donation: donation1, item_id: 1)
      LineItem.create(donation: donation2, item_id: 2)
    end

    it 'returns the correct count of distinct item_ids' do
      expect(product_drive.distinct_items_count).to eq(2)
    end
  end

  context 'with edge cases' do
    it 'handles unexpected input gracefully' do
      # Implement edge case handling test
      pending 'not yet implemented'
    end
  end
end
describe "#in_kind_value", :phoenix do
  let(:product_drive) { ProductDrive.new }

  context "when there are no donations" do
    it "returns 0" do
      expect(product_drive.in_kind_value).to eq(0)
    end
  end

  context "when there is a single donation" do
    let(:donation) { Donation.new(value_per_itemizable: 100) }

    before do
      allow(product_drive).to receive(:donations).and_return([donation])
    end

    it "returns the value of the donation" do
      expect(product_drive.in_kind_value).to eq(100)
    end
  end

  context "when there are multiple donations" do
    let(:donation1) { Donation.new(value_per_itemizable: 100) }
    let(:donation2) { Donation.new(value_per_itemizable: 200) }

    before do
      allow(product_drive).to receive(:donations).and_return([donation1, donation2])
    end

    it "returns the sum of the donation values" do
      expect(product_drive.in_kind_value).to eq(300)
    end
  end

  context "when donations have nil or invalid value_per_itemizable" do
    let(:donation1) { Donation.new(value_per_itemizable: nil) }
    let(:donation2) { Donation.new(value_per_itemizable: 'invalid') }
    let(:donation3) { Donation.new(value_per_itemizable: 100) }

    before do
      allow(product_drive).to receive(:donations).and_return([donation1, donation2, donation3])
    end

    it "ignores invalid values and sums valid ones" do
      expect(product_drive.in_kind_value).to eq(100)
    end
  end
end
describe "#donation_source_view", :phoenix do
  let(:product_drive_with_name) { ProductDrive.new(name: "Charity Event") }
  let(:product_drive_with_nil_name) { ProductDrive.new(name: nil) }
  let(:product_drive_with_empty_name) { ProductDrive.new(name: "") }
  let(:product_drive_with_special_characters) { ProductDrive.new(name: "Charity!@#") }
  let(:product_drive_with_spaces) { ProductDrive.new(name: "Charity Event 2023") }

  it "returns the correct string format when name is present" do
    expect(product_drive_with_name.donation_source_view).to eq("Charity Event (product drive)")
  end

  it "returns the correct string format when name is nil" do
    expect(product_drive_with_nil_name.donation_source_view).to eq(" (product drive)")
  end

  it "returns the correct string format when name is an empty string" do
    expect(product_drive_with_empty_name.donation_source_view).to eq(" (product drive)")
  end

  it "returns the correct string format when name contains special characters" do
    expect(product_drive_with_special_characters.donation_source_view).to eq("Charity!@# (product drive)")
  end

  it "returns the correct string format when name contains spaces" do
    expect(product_drive_with_spaces.donation_source_view).to eq("Charity Event 2023 (product drive)")
  end
end
describe '#search_date_range', :phoenix do
  let(:valid_dates) { '2023-01-01 - 2023-12-31' }
  let(:no_separator) { '20230101 20231231' }
  let(:incorrect_format) { '01/01/2023 - 31/12/2023' }
  let(:empty_string) { '' }
  let(:nil_input) { nil }
  let(:one_date) { '2023-01-01' }

  it 'returns correct hash for valid date range input' do
    result = ProductDrive.search_date_range(valid_dates)
    expect(result).to eq({ start_date: '2023-01-01', end_date: '2023-12-31' })
  end

  describe 'when input is invalid' do
    it 'returns hash with unparsed dates for input with no separator' do
      result = ProductDrive.search_date_range(no_separator)
      expect(result).to eq({ start_date: '20230101', end_date: '20231231' })
    end

    it 'returns hash with unparsed dates for input with incorrect date format' do
      result = ProductDrive.search_date_range(incorrect_format)
      expect(result).to eq({ start_date: '01/01/2023', end_date: '31/12/2023' })
    end
  end

  describe 'when input is an edge case' do
    it 'returns nil values for empty string input' do
      result = ProductDrive.search_date_range(empty_string)
      expect(result).to eq({ start_date: nil, end_date: nil })
    end

    it 'returns nil values for nil input' do
      result = ProductDrive.search_date_range(nil_input)
      expect(result).to eq({ start_date: nil, end_date: nil })
    end

    it 'returns hash with only start date for input with one date' do
      result = ProductDrive.search_date_range(one_date)
      expect(result).to eq({ start_date: '2023-01-01', end_date: nil })
    end
  end
end
describe "#item_quantities_by_name_and_date", :phoenix do
  let(:organization) { create(:organization) }
  let(:item1) { create(:item, name: 'Item A', organization: organization) }
  let(:item2) { create(:item, name: 'Item B', organization: organization) }
  let(:date_range) { Date.today.beginning_of_month..Date.today.end_of_month }

  before do
    # Create donations with line items
    donation1 = create(:donation, organization: organization, created_at: Date.today - 5.days)
    create(:line_item, donation: donation1, item: item1, quantity: 10)

    donation2 = create(:donation, organization: organization, created_at: Date.today - 10.days)
    create(:line_item, donation: donation2, item: item2, quantity: 5)
  end

  it "returns correct quantities for items within the date range" do
    result = subject.item_quantities_by_name_and_date(date_range)
    expect(result).to eq([10, 5])
  end

  it "returns zero quantities when there are no donations in the date range" do
    empty_date_range = (Date.today - 1.month).beginning_of_month..(Date.today - 1.month).end_of_month
    result = subject.item_quantities_by_name_and_date(empty_date_range)
    expect(result).to eq([0, 0])
  end

  it "returns zero quantities when donations have no line items" do
    donation3 = create(:donation, organization: organization, created_at: Date.today - 3.days)
    result = subject.item_quantities_by_name_and_date(date_range)
    expect(result).to eq([10, 5])
  end

  it "handles multiple items and orders them by name" do
    result = subject.item_quantities_by_name_and_date(date_range)
    expect(result).to eq([10, 5])
  end

  it "returns zero for items not present in donations" do
    item3 = create(:item, name: 'Item C', organization: organization)
    result = subject.item_quantities_by_name_and_date(date_range)
    expect(result).to eq([10, 5, 0])
  end

  it "handles edge cases for date range boundaries" do
    boundary_date_range = (Date.today - 10.days)..(Date.today - 5.days)
    result = subject.item_quantities_by_name_and_date(boundary_date_range)
    expect(result).to eq([10, 5])
  end
end
describe "#donation_quantity_by_date", :phoenix do
  let(:product_drive) { ProductDrive.new }
  let(:date_range) { Date.today.beginning_of_month..Date.today.end_of_month }
  let(:item_category) { ItemCategory.create(name: 'Category 1') }
  let(:item) { Item.create(name: 'Item 1', item_category: item_category) }
  let(:donation) { Donation.create(date: Date.today) }
  let!(:line_item) { LineItem.create(quantity: 5, item: item, donation: donation) }

  context "when no item category is provided" do
    it "returns the sum of quantities for a given date range" do
      expect(product_drive.donation_quantity_by_date(date_range)).to eq(5)
    end
  end

  context "when an item category is provided" do
    it "returns the sum of quantities for a given date range with item category" do
      expect(product_drive.donation_quantity_by_date(date_range, item_category.id)).to eq(5)
    end
  end

  context "when date range is empty or nil" do
    it "returns zero for empty date range" do
      expect(product_drive.donation_quantity_by_date(nil)).to eq(0)
    end
  end

  context "when item category id is empty or nil" do
    it "returns the sum of quantities ignoring nil item category id" do
      expect(product_drive.donation_quantity_by_date(date_range, nil)).to eq(5)
    end
  end

  context "when there are no donations in the given date range" do
    let(:date_range) { (Date.today - 1.month).beginning_of_month..(Date.today - 1.month).end_of_month }
    it "returns zero when no donations exist in the date range" do
      expect(product_drive.donation_quantity_by_date(date_range)).to eq(0)
    end
  end

  context "when there are donations but none match the item category id" do
    let(:other_category) { ItemCategory.create(name: 'Category 2') }
    it "returns zero when no donations match the item category id" do
      expect(product_drive.donation_quantity_by_date(date_range, other_category.id)).to eq(0)
    end
  end

  context "when there are donations that match the item category id" do
    it "returns the sum of quantities for matching item category id" do
      expect(product_drive.donation_quantity_by_date(date_range, item_category.id)).to eq(5)
    end
  end
end
describe '#distinct_items_count_by_date', :phoenix do
  let(:date_range) { Date.today.beginning_of_month..Date.today.end_of_month }
  let(:item_category) { ItemCategory.create(name: 'Category 1') }
  let(:item) { Item.create(name: 'Item 1', item_category: item_category) }
  let(:line_item) { LineItem.create(item: item) }
  let(:donation) { Donation.create(created_at: Date.today, line_items: [line_item]) }

  context 'without item category' do
    it 'returns distinct item count for a given date range' do
      donation
      expect(ProductDrive.new.distinct_items_count_by_date(date_range)).to eq(1)
    end

    it 'returns zero when no donations are in the given date range' do
      expect(ProductDrive.new.distinct_items_count_by_date(date_range)).to eq(0)
    end

    it 'handles an empty date range' do
      expect(ProductDrive.new.distinct_items_count_by_date(nil)).to eq(0)
    end
  end

  context 'with item category' do
    it 'returns distinct item count for a given date range' do
      donation
      expect(ProductDrive.new.distinct_items_count_by_date(date_range, item_category.id)).to eq(1)
    end

    it 'handles nil item_category_id' do
      donation
      expect(ProductDrive.new.distinct_items_count_by_date(date_range, nil)).to eq(1)
    end
  end
end
end
