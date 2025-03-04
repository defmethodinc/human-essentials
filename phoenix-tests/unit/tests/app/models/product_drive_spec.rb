
require "rails_helper"

RSpec.describe ProductDrive do
describe "#end_date_is_bigger_of_end_date", :phoenix do
  let(:product_drive) { ProductDrive.new(start_date: start_date, end_date: end_date) }

  context "when start_date and end_date are nil" do
    let(:start_date) { nil }
    let(:end_date) { nil }

    it "does not add errors when both dates are nil" do
      product_drive.valid?
      expect(product_drive.errors[:end_date]).to be_empty
    end
  end

  context "when end_date is before start_date" do
    let(:start_date) { Date.today }
    let(:end_date) { Date.yesterday }

    it "adds an error when end_date is before start_date" do
      product_drive.valid?
      expect(product_drive.errors[:end_date]).to include('End date must be after the start date')
    end
  end

  context "when end_date is after start_date" do
    let(:start_date) { Date.yesterday }
    let(:end_date) { Date.today }

    it "does not add errors when end_date is after start_date" do
      product_drive.valid?
      expect(product_drive.errors[:end_date]).to be_empty
    end
  end
end
describe '#donation_quantity', :phoenix do
  let(:product_drive) { ProductDrive.new }

  it 'returns zero when there are no donations' do
    expect(product_drive.donation_quantity).to eq(0)
  end

  context 'when there are donations' do
    context 'and donations have no line items' do
      let!(:donation_without_line_items) { Donation.create }

      it 'returns zero' do
        expect(product_drive.donation_quantity).to eq(0)
      end
    end

    context 'and donations have line items' do
      let!(:donation_with_line_items) do
        donation = Donation.create
        LineItem.create(donation: donation, quantity: 5)
        donation
      end

      it 'calculates the total quantity for a single donation' do
        expect(product_drive.donation_quantity).to eq(5)
      end
    end

    context 'and there are multiple donations with line items' do
      let!(:multiple_donations_with_line_items) do
        donation1 = Donation.create
        donation2 = Donation.create
        LineItem.create(donation: donation1, quantity: 3)
        LineItem.create(donation: donation2, quantity: 7)
        [donation1, donation2]
      end

      it 'calculates the total quantity for multiple donations' do
        expect(product_drive.donation_quantity).to eq(10)
      end
    end
  end

  context 'edge cases' do
    it 'handles negative quantities' do
      donation = Donation.create
      LineItem.create(donation: donation, quantity: -5)
      expect(product_drive.donation_quantity).to eq(-5)
    end

    it 'handles very large quantities' do
      donation = Donation.create
      LineItem.create(donation: donation, quantity: 1_000_000)
      expect(product_drive.donation_quantity).to eq(1_000_000)
    end
  end
end
describe '#distinct_items_count', :phoenix do
  let(:product_drive) { ProductDrive.create }

  it 'returns 0 when there are no donations' do
    expect(product_drive.distinct_items_count).to eq(0)
  end

  it 'returns 0 when there are donations but no line items' do
    Donation.create(product_drive: product_drive)
    expect(product_drive.distinct_items_count).to eq(0)
  end

  it 'returns the correct count when there are donations with distinct item IDs' do
    donation = Donation.create(product_drive: product_drive)
    LineItem.create(donation: donation, item_id: 1)
    LineItem.create(donation: donation, item_id: 2)
    expect(product_drive.distinct_items_count).to eq(2)
  end

  it 'returns the correct count when there are donations with duplicate item IDs' do
    donation = Donation.create(product_drive: product_drive)
    LineItem.create(donation: donation, item_id: 1)
    LineItem.create(donation: donation, item_id: 1)
    expect(product_drive.distinct_items_count).to eq(1)
  end

  it 'returns the correct count when there are multiple donations with overlapping line items' do
    donation1 = Donation.create(product_drive: product_drive)
    donation2 = Donation.create(product_drive: product_drive)
    LineItem.create(donation: donation1, item_id: 1)
    LineItem.create(donation: donation1, item_id: 2)
    LineItem.create(donation: donation2, item_id: 2)
    LineItem.create(donation: donation2, item_id: 3)
    expect(product_drive.distinct_items_count).to eq(3)
  end
end
describe '#in_kind_value', :phoenix do
  let(:product_drive) { create(:product_drive) }
  let(:donation_with_value) { build(:donation, value_per_itemizable: 100) }
  let(:donation_with_nil_value) { build(:donation, value_per_itemizable: nil) }
  let(:donation_with_zero_value) { build(:donation, value_per_itemizable: 0) }
  let(:donation_with_negative_value) { build(:donation, value_per_itemizable: -50) }

  it 'returns 0 when there are no donations' do
    allow(product_drive).to receive(:donations).and_return([])
    expect(product_drive.in_kind_value).to eq(0)
  end

  it 'returns the value of a single donation' do
    allow(product_drive).to receive(:donations).and_return([donation_with_value])
    expect(product_drive.in_kind_value).to eq(100)
  end

  it 'returns the sum of values for multiple donations' do
    allow(product_drive).to receive(:donations).and_return([donation_with_value, donation_with_value])
    expect(product_drive.in_kind_value).to eq(200)
  end

  it 'returns 0 for donations with nil value_per_itemizable' do
    allow(product_drive).to receive(:donations).and_return([donation_with_nil_value])
    expect(product_drive.in_kind_value).to eq(0)
  end

  it 'returns 0 for donations with zero value_per_itemizable' do
    allow(product_drive).to receive(:donations).and_return([donation_with_zero_value])
    expect(product_drive.in_kind_value).to eq(0)
  end

  it 'returns the sum including negative values for donations' do
    allow(product_drive).to receive(:donations).and_return([donation_with_negative_value])
    expect(product_drive.in_kind_value).to eq(-50)
  end
end
describe "#donation_source_view", :phoenix do
  let(:product_drive_with_valid_name) { ProductDrive.new(name: "Valid Name") }
  let(:product_drive_with_empty_name) { ProductDrive.new(name: "") }
  let(:product_drive_with_nil_name) { ProductDrive.new(name: nil) }
  let(:product_drive_with_special_characters) { ProductDrive.new(name: "Special!@#") }

  it "returns the correct string when name is a valid string" do
    expect(product_drive_with_valid_name.donation_source_view).to eq("Valid Name (product drive)")
  end

  it "returns the correct string when name is an empty string" do
    expect(product_drive_with_empty_name.donation_source_view).to eq(" (product drive)")
  end

  it "returns the correct string when name is nil" do
    expect(product_drive_with_nil_name.donation_source_view).to eq(" (product drive)")
  end

  it "returns the correct string when name contains special characters" do
    expect(product_drive_with_special_characters.donation_source_view).to eq("Special!@# (product drive)")
  end
end
describe '.search_date_range', :phoenix do
  let(:valid_dates) { '2023-01-01 - 2023-12-31' }
  let(:no_separator) { '20230101 20231231' }
  let(:multiple_separators) { '2023-01-01 - - 2023-12-31' }
  let(:empty_string) { '' }
  let(:non_date_values) { 'abc - xyz' }
  let(:one_date) { '2023-01-01' }
  let(:leading_trailing_spaces) { ' 2023-01-01 - 2023-12-31 ' }

  it 'returns correct hash for valid date range input' do
    result = ProductDrive.search_date_range(valid_dates)
    expect(result).to eq({ start_date: '2023-01-01', end_date: '2023-12-31' })
  end

  describe 'when input is invalid' do
    it 'returns nil for start_date and end_date when no separator is present' do
      result = ProductDrive.search_date_range(no_separator)
      expect(result).to eq({ start_date: nil, end_date: nil })
    end

    it 'returns nil for start_date and end_date when multiple separators are present' do
      result = ProductDrive.search_date_range(multiple_separators)
      expect(result).to eq({ start_date: nil, end_date: nil })
    end

    it 'returns nil for start_date and end_date when input is an empty string' do
      result = ProductDrive.search_date_range(empty_string)
      expect(result).to eq({ start_date: nil, end_date: nil })
    end

    it 'returns nil for start_date and end_date when input contains non-date values' do
      result = ProductDrive.search_date_range(non_date_values)
      expect(result).to eq({ start_date: nil, end_date: nil })
    end
  end

  describe 'when input is an edge case' do
    it 'returns correct hash when input contains only one date' do
      result = ProductDrive.search_date_range(one_date)
      expect(result).to eq({ start_date: '2023-01-01', end_date: nil })
    end

    it 'returns correct hash when input has leading or trailing spaces' do
      result = ProductDrive.search_date_range(leading_trailing_spaces.strip)
      expect(result).to eq({ start_date: '2023-01-01', end_date: '2023-12-31' })
    end
  end
end
describe "#item_quantities_by_name_and_date", :phoenix do
  let(:organization) { Organization.create(name: 'Test Organization') }
  let(:product_drive) { ProductDrive.create(organization: organization) }
  let(:item1) { Item.create(name: 'Item 1', organization: organization) }
  let(:item2) { Item.create(name: 'Item 2', organization: organization) }
  let(:item3) { Item.create(name: 'Item 3', organization: organization) }

  it "returns zero quantities when there are no donations in the date range" do
    date_range = (Date.today - 7)..(Date.today - 1)
    expect(product_drive.item_quantities_by_name_and_date(date_range)).to eq([0, 0, 0])
  end

  it "returns zero quantities when there are donations but no line items" do
    Donation.create(product_drive: product_drive, created_at: Date.today)
    date_range = Date.today..Date.today
    expect(product_drive.item_quantities_by_name_and_date(date_range)).to eq([0, 0, 0])
  end

  it "calculates quantities correctly when all items have quantities" do
    donation = Donation.create(product_drive: product_drive, created_at: Date.today)
    LineItem.create(donation: donation, item: item1, quantity: 5)
    LineItem.create(donation: donation, item: item2, quantity: 10)
    date_range = Date.today..Date.today
    expect(product_drive.item_quantities_by_name_and_date(date_range)).to eq([5, 10, 0])
  end

  it "handles items with zero quantities correctly" do
    donation = Donation.create(product_drive: product_drive, created_at: Date.today)
    LineItem.create(donation: donation, item: item1, quantity: 0)
    LineItem.create(donation: donation, item: item2, quantity: 10)
    date_range = Date.today..Date.today
    expect(product_drive.item_quantities_by_name_and_date(date_range)).to eq([0, 10, 0])
  end

  it "includes all organization items even if not present in line items" do
    donation = Donation.create(product_drive: product_drive, created_at: Date.today)
    LineItem.create(donation: donation, item: item2, quantity: 10)
    date_range = Date.today..Date.today
    expect(product_drive.item_quantities_by_name_and_date(date_range)).to eq([0, 10, 0])
  end
end
describe "#donation_quantity_by_date", :phoenix do
  let(:date_range) { Date.today.beginning_of_month..Date.today.end_of_month }
  let(:item_category) { ItemCategory.create!(name: "Category 1") }
  let(:item) { Item.create!(name: "Item 1", item_category: item_category) }
  let(:line_item) { LineItem.create!(item: item, quantity: 10) }
  let(:donation) { Donation.create!(date: Date.today, line_items: [line_item]) }

  context "without item category" do
    it "returns the sum of quantities for a given date range" do
      donation
      expect(ProductDrive.new.donation_quantity_by_date(date_range)).to eq(10)
    end
  end

  context "with item category" do
    it "returns the sum of quantities for a given date range" do
      donation
      expect(ProductDrive.new.donation_quantity_by_date(date_range, item_category.id)).to eq(10)
    end
  end

  context "when date range is empty" do
    it "returns zero" do
      expect(ProductDrive.new.donation_quantity_by_date(nil)).to eq(0)
    end
  end

  context "when date range is nil" do
    it "returns zero" do
      expect(ProductDrive.new.donation_quantity_by_date(nil)).to eq(0)
    end
  end

  context "when item category ID is nil" do
    it "returns the sum of quantities for a given date range" do
      donation
      expect(ProductDrive.new.donation_quantity_by_date(date_range, nil)).to eq(10)
    end
  end

  context "when item category ID is invalid" do
    it "returns zero" do
      donation
      expect(ProductDrive.new.donation_quantity_by_date(date_range, -1)).to eq(0)
    end
  end

  context "when no donations in the date range" do
    it "returns zero" do
      expect(ProductDrive.new.donation_quantity_by_date(date_range)).to eq(0)
    end
  end

  context "when donations exist in the date range" do
    it "returns the sum of quantities" do
      donation
      expect(ProductDrive.new.donation_quantity_by_date(date_range)).to eq(10)
    end
  end
end
describe "#distinct_items_count_by_date", :phoenix do
  let(:date_range) { Date.today.beginning_of_month..Date.today.end_of_month }
  let(:item_category) { ItemCategory.create(name: 'Category 1') }
  let(:item) { Item.create(name: 'Item 1', item_category: item_category) }
  let(:donation) { Donation.create(date: Date.today) }
  let(:line_item) { LineItem.create(donation: donation, item: item) }

  context "when there are donations with line items" do
    before do
      donation
      line_item
    end

    it "returns distinct item count for a given date range with no item category" do
      expect(ProductDrive.new.distinct_items_count_by_date(date_range)).to eq(1)
    end

    it "returns distinct item count for a given date range with a specific item category" do
      expect(ProductDrive.new.distinct_items_count_by_date(date_range, item_category.id)).to eq(1)
    end
  end

  context "when date range is empty or invalid" do
    it "returns zero" do
      expect(ProductDrive.new.distinct_items_count_by_date(nil)).to eq(0)
    end
  end

  context "when there are no donations in the given date range" do
    it "returns zero" do
      expect(ProductDrive.new.distinct_items_count_by_date(date_range)).to eq(0)
    end
  end

  context "when there are donations but no line items" do
    before do
      donation
    end

    it "returns zero" do
      expect(ProductDrive.new.distinct_items_count_by_date(date_range)).to eq(0)
    end
  end

  context "when there are donations with line items but no distinct items" do
    before do
      donation
      LineItem.create(donation: donation, item: item)
    end

    it "returns zero" do
      expect(ProductDrive.new.distinct_items_count_by_date(date_range)).to eq(0)
    end
  end
end
end
