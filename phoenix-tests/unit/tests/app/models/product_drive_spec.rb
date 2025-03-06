
require "rails_helper"

RSpec.describe ProductDrive do
describe '#end_date_is_bigger_of_end_date', :phoenix do
  let(:product_drive) { build(:product_drive, start_date: start_date, end_date: end_date) }

  context 'when both start_date and end_date are nil' do
    let(:start_date) { nil }
    let(:end_date) { nil }

    it 'does nothing' do
      product_drive.valid?
      expect(product_drive.errors[:end_date]).to be_empty
    end
  end

  context 'when start_date is nil and end_date is not nil' do
    let(:start_date) { nil }
    let(:end_date) { Date.today }

    it 'does nothing' do
      product_drive.valid?
      expect(product_drive.errors[:end_date]).to be_empty
    end
  end

  context 'when end_date is nil and start_date is not nil' do
    let(:start_date) { Date.today }
    let(:end_date) { nil }

    it 'does nothing' do
      product_drive.valid?
      expect(product_drive.errors[:end_date]).to be_empty
    end
  end

  context 'when end_date is greater than start_date' do
    let(:start_date) { Date.today }
    let(:end_date) { Date.tomorrow }

    it 'does nothing' do
      product_drive.valid?
      expect(product_drive.errors[:end_date]).to be_empty
    end
  end

  context 'when end_date is less than start_date' do
    let(:start_date) { Date.tomorrow }
    let(:end_date) { Date.today }

    it 'adds an error' do
      product_drive.valid?
      expect(product_drive.errors[:end_date]).to include('End date must be after the start date')
    end
  end
end
describe '#donation_quantity', :phoenix do
  let(:organization) { create(:organization) }
  let(:product_drive) { create(:product_drive, organization: organization) }
  let(:donation_with_items) { build(:donation, :with_items, product_drive: product_drive, organization: organization, item_quantity: 5) }
  let(:donation_without_items) { build(:donation, product_drive: product_drive, organization: organization) }
  let(:large_quantity_donation) { build(:donation, :with_items, product_drive: product_drive, organization: organization, item_quantity: 1_000_000) }
  let(:negative_quantity_donation) { build(:donation, :with_items, product_drive: product_drive, organization: organization, item_quantity: -5) }

  it 'sums the quantities of line items associated with donations' do
    donation_with_items.save
    expect(product_drive.donation_quantity).to eq(5)
  end

  it 'returns zero when there are no donations' do
    expect(product_drive.donation_quantity).to eq(0)
  end

  it 'returns zero for donations without line items' do
    donation_without_items.save
    expect(product_drive.donation_quantity).to eq(0)
  end

  it 'sums quantities for multiple donations with line items' do
    donation_with_items.save
    another_donation_with_items = build(:donation, :with_items, product_drive: product_drive, organization: organization, item_quantity: 10)
    another_donation_with_items.save
    expect(product_drive.donation_quantity).to eq(15)
  end

  it 'handles negative quantities' do
    negative_quantity_donation.save
    expect(product_drive.donation_quantity).to eq(-5)
  end

  it 'handles very large quantities' do
    large_quantity_donation.save
    expect(product_drive.donation_quantity).to eq(1_000_000)
  end

  it 'performs efficiently with a large dataset' do
    1000.times { build(:donation, :with_items, product_drive: product_drive, organization: organization, item_quantity: 1).save }
    expect(product_drive.donation_quantity).to eq(1000)
  end
end
describe '#distinct_items_count', :phoenix do
  let(:organization) { create(:organization) }
  let(:product_drive) { create(:product_drive, organization: organization) }
  let(:donation_with_items) { create(:donation, :with_items, product_drive: product_drive, organization: organization) }
  let(:donation_without_items) { create(:donation, product_drive: product_drive, organization: organization) }

  it 'returns 0 when there are no donations' do
    expect(product_drive.distinct_items_count).to eq(0)
  end

  it 'returns 0 when donations have no line items' do
    donation_without_items
    expect(product_drive.distinct_items_count).to eq(0)
  end

  it 'returns the correct count when all item_ids are distinct' do
    donation_with_items
    expect(product_drive.distinct_items_count).to eq(donation_with_items.line_items.count)
  end

  describe 'when there are duplicate item_ids' do
    before do
      create(:line_item, item_id: donation_with_items.line_items.first.item_id, donation: donation_with_items)
    end

    it 'returns the correct distinct count' do
      expect(product_drive.distinct_items_count).to eq(donation_with_items.line_items.distinct.count)
    end
  end
end
describe '#in_kind_value', :phoenix do
  let(:organization) { create(:organization) }
  let(:product_drive) { build(:product_drive, organization: organization) }

  before do
    allow(product_drive).to receive(:donations).and_return(donations)
  end

  context 'when donations collection is empty' do
    let(:donations) { [] }

    it 'returns 0' do
      expect(product_drive.in_kind_value).to eq(0)
    end
  end

  context 'when donations have no line items' do
    let(:donations) { build_list(:donation, 3, product_drive: product_drive, organization: organization) }

    it 'returns 0' do
      expect(product_drive.in_kind_value).to eq(0)
    end
  end

  context 'when donations have positive line item values' do
    let(:donations) do
      build_list(:donation, 3, :with_items, item_quantity: 5, product_drive: product_drive, organization: organization)
    end

    it 'calculates the sum of positive values from line items' do
      total_value = donations.sum { |donation| donation.value_per_itemizable }
      expect(product_drive.in_kind_value).to eq(total_value)
    end
  end

  context 'when line items have zero values' do
    let(:donations) do
      build_list(:donation, 3, :with_items, item_quantity: 0, product_drive: product_drive, organization: organization)
    end

    it 'returns 0 when line items have zero values' do
      expect(product_drive.in_kind_value).to eq(0)
    end
  end

  context 'when line items have negative values' do
    let(:donations) do
      build_list(:donation, 3, :with_items, item_quantity: -5, product_drive: product_drive, organization: organization)
    end

    it 'calculates the sum when line items have negative values' do
      total_value = donations.sum { |donation| donation.value_per_itemizable }
      expect(product_drive.in_kind_value).to eq(total_value)
    end
  end
end
describe '#donation_source_view', :phoenix do
  let(:product_drive_with_name) { build(:product_drive, name: 'Test Drive') }
  let(:product_drive_empty_name) { build(:product_drive, name: '') }
  let(:product_drive_special_chars) { build(:product_drive, name: '@Special!') }
  let(:product_drive_nil_name) { build(:product_drive, name: nil) }

  it 'returns the name with (product drive) for a regular name' do
    expect(product_drive_with_name.donation_source_view).to eq('Test Drive (product drive)')
  end

  it 'returns (product drive) when name is empty' do
    expect(product_drive_empty_name.donation_source_view).to eq('(product drive)')
  end

  it 'handles special characters in the name' do
    expect(product_drive_special_chars.donation_source_view).to eq('@Special! (product drive)')
  end

  it 'handles nil name gracefully' do
    expect(product_drive_nil_name.donation_source_view).to eq('(product drive)')
  end
end
describe '.search_date_range', :phoenix do
  let(:valid_date_range) { '2023-01-01 - 2023-12-31' }
  let(:invalid_date_format) { '01/01/2023 - 12/31/2023' }
  let(:invalid_date_values) { '2023-02-30 - 2023-02-31' }
  let(:empty_string) { '' }
  let(:whitespace_string) { '   ' }
  let(:single_date) { '2023-01-01' }
  let(:reversed_date_range) { '2023-12-31 - 2023-01-01' }
  let(:non_date_strings) { 'start - end' }
  let(:leap_year_dates) { '2024-02-29 - 2024-03-01' }
  let(:boundary_date_values) { '2023-01-01 - 2023-12-31' }

  it 'parses a valid date range' do
    result = ProductDrive.search_date_range(valid_date_range)
    expect(result).to eq({ start_date: '2023-01-01', end_date: '2023-12-31' })
  end

  it 'returns input for invalid date format' do
    result = ProductDrive.search_date_range(invalid_date_format)
    expect(result).to eq({ start_date: '01/01/2023', end_date: '12/31/2023' })
  end

  it 'returns input for invalid date values' do
    result = ProductDrive.search_date_range(invalid_date_values)
    expect(result).to eq({ start_date: '2023-02-30', end_date: '2023-02-31' })
  end

  it 'returns nil for empty string' do
    result = ProductDrive.search_date_range(empty_string)
    expect(result).to eq({ start_date: nil, end_date: nil })
  end

  it 'returns nil for whitespace string' do
    result = ProductDrive.search_date_range(whitespace_string)
    expect(result).to eq({ start_date: nil, end_date: nil })
  end

  it 'returns single date with nil end date' do
    result = ProductDrive.search_date_range(single_date)
    expect(result).to eq({ start_date: '2023-01-01', end_date: nil })
  end

  it 'returns reversed date range as is' do
    result = ProductDrive.search_date_range(reversed_date_range)
    expect(result).to eq({ start_date: '2023-12-31', end_date: '2023-01-01' })
  end

  it 'returns input for non-date strings' do
    result = ProductDrive.search_date_range(non_date_strings)
    expect(result).to eq({ start_date: 'start', end_date: 'end' })
  end

  it 'parses leap year dates correctly' do
    result = ProductDrive.search_date_range(leap_year_dates)
    expect(result).to eq({ start_date: '2024-02-29', end_date: '2024-03-01' })
  end

  it 'parses boundary date values correctly' do
    result = ProductDrive.search_date_range(boundary_date_values)
    expect(result).to eq({ start_date: '2023-01-01', end_date: '2023-12-31' })
  end
end
describe "#item_quantities_by_name_and_date", :phoenix do
  let(:organization) { create(:organization) }
  let(:item1) { create(:item, organization: organization) }
  let(:item2) { create(:item, organization: organization) }
  let(:donation1) { create(:donation, :with_items, organization: organization, item: item1, item_quantity: 10, created_at: Time.zone.today - 3.days) }
  let(:donation2) { create(:donation, :with_items, organization: organization, item: item2, item_quantity: 5, created_at: Time.zone.today - 2.days) }
  let(:date_range) { (Time.zone.today - 1.week)..Time.zone.today }

  it "returns correct quantities for items within the date range" do
    quantities = organization.item_quantities_by_name_and_date(date_range)
    expect(quantities).to eq([10, 5])
  end

  it "returns zero quantities for an empty date range" do
    empty_range = (Time.zone.today + 1.day)..(Time.zone.today + 2.days)
    quantities = organization.item_quantities_by_name_and_date(empty_range)
    expect(quantities).to eq([0, 0])
  end

  it "returns zero quantities when there are no donations" do
    allow(organization).to receive(:donations).and_return(Donation.none)
    quantities = organization.item_quantities_by_name_and_date(date_range)
    expect(quantities).to eq([0, 0])
  end

  it "returns zero quantities when there are no line items" do
    allow(donation1).to receive(:line_items).and_return(LineItem.none)
    allow(donation2).to receive(:line_items).and_return(LineItem.none)
    quantities = organization.item_quantities_by_name_and_date(date_range)
    expect(quantities).to eq([0, 0])
  end

  it "sums quantities for multiple items correctly" do
    donation3 = create(:donation, :with_items, organization: organization, item: item1, item_quantity: 15, created_at: Time.zone.today - 1.day)
    quantities = organization.item_quantities_by_name_and_date(date_range)
    expect(quantities).to eq([25, 5])
  end

  it "returns an empty array when there are no items" do
    allow(organization).to receive(:items).and_return(Item.none)
    quantities = organization.item_quantities_by_name_and_date(date_range)
    expect(quantities).to eq([])
  end

  it "handles boundary dates correctly" do
    donation4 = create(:donation, :with_items, organization: organization, item: item1, item_quantity: 20, created_at: date_range.first)
    donation5 = create(:donation, :with_items, organization: organization, item: item2, item_quantity: 30, created_at: date_range.last)
    quantities = organization.item_quantities_by_name_and_date(date_range)
    expect(quantities).to eq([30, 35])
  end
end
describe '#donation_quantity_by_date', :phoenix do
  let(:organization) { create(:organization) }
  let(:item_category) { create(:item_category, organization: organization) }
  let(:item) { create(:item, organization: organization, item_category: item_category) }
  let(:donation) { create(:donation, :with_items, organization: organization, item: item) }
  let(:line_item) { create(:line_item, item: item, itemizable: donation, quantity: 5) }
  let(:date_range) { (Time.zone.today.beginning_of_month..Time.zone.today.end_of_month) }

  subject { ProductDrive.new.donation_quantity_by_date(date_range, item_category_id) }

  context 'when item_category_id is provided' do
    let(:item_category_id) { item_category.id }

    it 'sums the quantity of line_items for the given item_category_id' do
      expect(subject).to eq(5)
    end
  end

  context 'when item_category_id is not provided' do
    let(:item_category_id) { nil }

    it 'sums the quantity of all line_items' do
      expect(subject).to eq(5)
    end
  end

  context 'when date_range is provided' do
    let(:item_category_id) { nil }

    it 'filters donations by the given date_range' do
      expect(subject).to eq(5)
    end
  end

  context 'edge cases' do
    let(:item_category_id) { nil }

    it 'handles empty date_range' do
      empty_date_range = (Time.zone.today..Time.zone.today)
      expect(ProductDrive.new.donation_quantity_by_date(empty_date_range, item_category_id)).to eq(0)
    end

    it 'handles invalid date_range' do
      invalid_date_range = (Time.zone.today..Time.zone.today - 1.day)
      expect(ProductDrive.new.donation_quantity_by_date(invalid_date_range, item_category_id)).to eq(0)
    end

    it 'handles no donations in the given date_range' do
      future_date_range = (Time.zone.today.next_month.beginning_of_month..Time.zone.today.next_month.end_of_month)
      expect(ProductDrive.new.donation_quantity_by_date(future_date_range, item_category_id)).to eq(0)
    end

    it 'handles no line items for the given item_category_id' do
      different_item_category = create(:item_category, organization: organization)
      expect(ProductDrive.new.donation_quantity_by_date(date_range, different_item_category.id)).to eq(0)
    end
  end
end
describe "#distinct_items_count_by_date", :phoenix do
  let(:organization) { create(:organization) }
  let(:item_category) { create(:item_category, organization: organization) }
  let(:item) { create(:item, organization: organization, item_category: item_category) }
  let(:donation) { create(:donation, :with_items, organization: organization, item: item) }

  context "without item category" do
    let(:date_range) { Date.today.beginning_of_month..Date.today.end_of_month }
    let!(:donation1) { create(:donation, :with_items, organization: organization, issued_at: Date.today, item: item) }
    let!(:donation2) { create(:donation, :with_items, organization: organization, issued_at: Date.today, item: item) }

    it "returns distinct item count for a given date range" do
      expect(donation.distinct_items_count_by_date(date_range)).to eq(1)
    end
  end

  context "with item category" do
    let(:date_range) { Date.today.beginning_of_month..Date.today.end_of_month }
    let!(:donation1) { create(:donation, :with_items, organization: organization, issued_at: Date.today, item: item) }

    it "returns distinct item count for a given date range with item category" do
      expect(donation.distinct_items_count_by_date(date_range, item_category.id)).to eq(1)
    end
  end

  describe "when item_category_id is present" do
    let(:date_range) { Date.today.beginning_of_month..Date.today.end_of_month }

    context "and items match the category" do
      let!(:donation1) { create(:donation, :with_items, organization: organization, issued_at: Date.today, item: item) }

      it "returns distinct item count" do
        expect(donation.distinct_items_count_by_date(date_range, item_category.id)).to eq(1)
      end
    end

    context "and no items match the category" do
      let(:other_item) { create(:item, organization: organization) }
      let!(:donation1) { create(:donation, :with_items, organization: organization, issued_at: Date.today, item: other_item) }

      it "returns zero" do
        expect(donation.distinct_items_count_by_date(date_range, item_category.id)).to eq(0)
      end
    end
  end

  context "with empty or invalid date range" do
    let(:date_range) { nil }

    it "handles empty or invalid date range" do
      expect(donation.distinct_items_count_by_date(date_range)).to eq(0)
    end
  end

  context "when there are no donations in the date range" do
    let(:date_range) { Date.today.beginning_of_month..Date.today.end_of_month }
    let!(:donation1) { create(:donation, :with_items, organization: organization, issued_at: Date.today.prev_month, item: item) }

    it "returns zero" do
      expect(donation.distinct_items_count_by_date(date_range)).to eq(0)
    end
  end
end
end
