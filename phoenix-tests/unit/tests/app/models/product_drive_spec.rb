
require "rails_helper"

RSpec.describe ProductDrive do
describe '#end_date_is_bigger_of_end_date', :phoenix do
  let(:product_drive_with_nil_start_date) { ProductDrive.new(start_date: nil, end_date: Date.today) }
  let(:product_drive_with_nil_end_date) { ProductDrive.new(start_date: Date.today, end_date: nil) }
  let(:product_drive_with_end_date_before_start_date) { ProductDrive.new(start_date: Date.today, end_date: Date.yesterday) }
  let(:product_drive_with_end_date_after_start_date) { ProductDrive.new(start_date: Date.yesterday, end_date: Date.today) }

  it 'does nothing if start_date is nil' do
    product_drive_with_nil_start_date.end_date_is_bigger_of_end_date
    expect(product_drive_with_nil_start_date.errors[:end_date]).to be_empty
  end

  it 'does nothing if end_date is nil' do
    product_drive_with_nil_end_date.end_date_is_bigger_of_end_date
    expect(product_drive_with_nil_end_date.errors[:end_date]).to be_empty
  end

  it 'adds an error if end_date is less than start_date' do
    product_drive_with_end_date_before_start_date.end_date_is_bigger_of_end_date
    expect(product_drive_with_end_date_before_start_date.errors[:end_date]).to include('End date must be after the start date')
  end

  it 'does nothing if end_date is greater than start_date' do
    product_drive_with_end_date_after_start_date.end_date_is_bigger_of_end_date
    expect(product_drive_with_end_date_after_start_date.errors[:end_date]).to be_empty
  end
end
describe '#donation_quantity', :phoenix do
  let(:product_drive) { ProductDrive.new }

  it 'returns zero when there are no donations' do
    expect(product_drive.donation_quantity).to eq(0)
  end

  context 'when donations have no line items' do
    let!(:donation) { Donation.create(product_drive: product_drive) }

    it 'returns zero' do
      expect(product_drive.donation_quantity).to eq(0)
    end
  end

  context 'when donations have line items' do
    let!(:donation) { Donation.create(product_drive: product_drive) }
    let!(:line_item) { LineItem.create(donation: donation, quantity: 5) }

    it 'calculates the sum of quantities for donations with line items' do
      expect(product_drive.donation_quantity).to eq(5)
    end
  end

  context 'with multiple donations having line items' do
    let!(:donation1) { Donation.create(product_drive: product_drive) }
    let!(:line_item1) { LineItem.create(donation: donation1, quantity: 5) }
    let!(:donation2) { Donation.create(product_drive: product_drive) }
    let!(:line_item2) { LineItem.create(donation: donation2, quantity: 10) }

    it 'calculates the sum of quantities for multiple donations with line items' do
      expect(product_drive.donation_quantity).to eq(15)
    end
  end

  context 'handling edge cases' do
    context 'with negative quantities' do
      let!(:donation) { Donation.create(product_drive: product_drive) }
      let!(:line_item) { LineItem.create(donation: donation, quantity: -5) }

      it 'returns the sum of negative quantities' do
        expect(product_drive.donation_quantity).to eq(-5)
      end
    end

    context 'with very large numbers' do
      let!(:donation) { Donation.create(product_drive: product_drive) }
      let!(:line_item) { LineItem.create(donation: donation, quantity: 1_000_000) }

      it 'returns the sum of large quantities' do
        expect(product_drive.donation_quantity).to eq(1_000_000)
      end
    end
  end
end
describe '#distinct_items_count', :phoenix do
  let(:product_drive) { ProductDrive.create(name: 'Test Drive') }

  context 'when there are no donations' do
    it 'returns 0' do
      expect(product_drive.distinct_items_count).to eq(0)
    end
  end

  context 'when donations have no line items' do
    before do
      Donation.create(product_drive: product_drive)
    end

    it 'returns 0' do
      expect(product_drive.distinct_items_count).to eq(0)
    end
  end

  context 'when donations have unique line items' do
    before do
      donation = Donation.create(product_drive: product_drive)
      LineItem.create(donation: donation, item_id: 1)
      LineItem.create(donation: donation, item_id: 2)
    end

    it 'returns the correct count' do
      expect(product_drive.distinct_items_count).to eq(2)
    end
  end

  context 'when donations have duplicate line items' do
    before do
      donation = Donation.create(product_drive: product_drive)
      LineItem.create(donation: donation, item_id: 1)
      LineItem.create(donation: donation, item_id: 1)
    end

    it 'returns the correct count' do
      expect(product_drive.distinct_items_count).to eq(1)
    end
  end

  context 'when donations have a mix of unique and duplicate line items' do
    before do
      donation1 = Donation.create(product_drive: product_drive)
      donation2 = Donation.create(product_drive: product_drive)
      LineItem.create(donation: donation1, item_id: 1)
      LineItem.create(donation: donation1, item_id: 2)
      LineItem.create(donation: donation2, item_id: 2)
      LineItem.create(donation: donation2, item_id: 3)
    end

    it 'returns the correct count' do
      expect(product_drive.distinct_items_count).to eq(3)
    end
  end
end
describe '#in_kind_value', :phoenix do
  let(:product_drive) { ProductDrive.new }

  it 'returns 0 when there are no donations' do
    expect(product_drive.in_kind_value).to eq(0)
  end

  context 'with a single donation' do
    let!(:donation) { Donation.create(value_per_itemizable: 100) }

    it 'returns the value of a single donation' do
      allow(product_drive).to receive(:donations).and_return([donation])
      expect(product_drive.in_kind_value).to eq(100)
    end
  end

  context 'with multiple donations' do
    let!(:donation1) { Donation.create(value_per_itemizable: 100) }
    let!(:donation2) { Donation.create(value_per_itemizable: 200) }

    it 'sums the values of multiple donations' do
      allow(product_drive).to receive(:donations).and_return([donation1, donation2])
      expect(product_drive.in_kind_value).to eq(300)
    end
  end

  context 'with donations having nil value_per_itemizable' do
    let!(:donation) { Donation.create(value_per_itemizable: nil) }

    it 'handles donations with nil value_per_itemizable' do
      allow(product_drive).to receive(:donations).and_return([donation])
      expect(product_drive.in_kind_value).to eq(0)
    end
  end

  context 'with donations having zero value_per_itemizable' do
    let!(:donation) { Donation.create(value_per_itemizable: 0) }

    it 'handles donations with zero value_per_itemizable' do
      allow(product_drive).to receive(:donations).and_return([donation])
      expect(product_drive.in_kind_value).to eq(0)
    end
  end

  context 'with donations having negative value_per_itemizable' do
    let!(:donation) { Donation.create(value_per_itemizable: -50) }

    it 'handles donations with negative value_per_itemizable' do
      allow(product_drive).to receive(:donations).and_return([donation])
      expect(product_drive.in_kind_value).to eq(-50)
    end
  end
end
describe "#donation_source_view", :phoenix do
  let(:product_drive) { ProductDrive.new(name: name) }
  let(:name) { "Typical Name" }

  it "returns the correct string with a typical name" do
    expect(product_drive.donation_source_view).to eq("Typical Name (product drive)")
  end

  describe "when name is an empty string" do
    let(:name) { "" }

    it "returns the correct string format" do
      expect(product_drive.donation_source_view).to eq(" (product drive)")
    end
  end

  describe "when name is nil" do
    let(:name) { nil }

    it "handles nil name gracefully" do
      expect(product_drive.donation_source_view).to eq(" (product drive)")
    end
  end
end
describe '.search_date_range', :phoenix do
  let(:valid_date_range) { '2023-01-01 - 2023-12-31' }
  let(:single_date) { '2023-01-01' }
  let(:empty_string) { '' }
  let(:no_separator) { '20230101' }
  let(:multiple_separators) { '2023-01-01 - 2023-12-31 - 2024-01-01' }
  let(:invalid_date_format) { '01-2023-01' }
  let(:non_date_strings) { 'not-a-date' }
  let(:nil_input) { nil }

  it 'returns correct hash for a valid date range' do
    result = ProductDrive.search_date_range(valid_date_range)
    expect(result).to eq({ start_date: '2023-01-01', end_date: '2023-12-31' })
  end

  it 'returns correct hash for a single date' do
    result = ProductDrive.search_date_range(single_date)
    expect(result).to eq({ start_date: '2023-01-01', end_date: nil })
  end

  it 'returns nil for both dates when input is an empty string' do
    result = ProductDrive.search_date_range(empty_string)
    expect(result).to eq({ start_date: nil, end_date: nil })
  end

  it 'returns correct hash when input has no separator' do
    result = ProductDrive.search_date_range(no_separator)
    expect(result).to eq({ start_date: '20230101', end_date: nil })
  end

  it 'returns correct hash for input with multiple separators' do
    result = ProductDrive.search_date_range(multiple_separators)
    expect(result).to eq({ start_date: '2023-01-01', end_date: '2023-12-31' })
  end

  it 'returns correct hash for invalid date format' do
    result = ProductDrive.search_date_range(invalid_date_format)
    expect(result).to eq({ start_date: '01-2023-01', end_date: nil })
  end

  it 'returns correct hash for non-date strings' do
    result = ProductDrive.search_date_range(non_date_strings)
    expect(result).to eq({ start_date: 'not-a-date', end_date: nil })
  end

  it 'returns nil for both dates when input is nil' do
    result = ProductDrive.search_date_range(nil_input)
    expect(result).to eq({ start_date: nil, end_date: nil })
  end
end
describe '#item_quantities_by_name_and_date', :phoenix do
  let(:organization) { create(:organization) }
  let(:items) { create_list(:item, 3, organization: organization) }
  let(:date_range) { Date.today.beginning_of_month..Date.today.end_of_month }

  it 'returns an array of quantities for each item ordered by name' do
    donations = create_list(:donation, 2, organization: organization)
    donations.each do |donation|
      items.each do |item|
        create(:line_item, donation: donation, item: item, quantity: rand(1..10))
      end
    end
    expected_quantities = items.sort_by(&:name).map do |item|
      donations.sum { |donation| donation.line_items.where(item: item).sum(:quantity) }
    end
    expect(subject.item_quantities_by_name_and_date(date_range)).to eq(expected_quantities)
  end

  context 'when there are no donations' do
    it 'returns an array of zeros for each item' do
      expected_quantities = Array.new(items.size, 0)
      expect(subject.item_quantities_by_name_and_date(date_range)).to eq(expected_quantities)
    end
  end

  context 'when donations have no line_items' do
    it 'returns an array of zeros for each item' do
      create_list(:donation, 2, organization: organization)
      expected_quantities = Array.new(items.size, 0)
      expect(subject.item_quantities_by_name_and_date(date_range)).to eq(expected_quantities)
    end
  end

  context 'when items are not in any donation' do
    it 'returns an array of zeros for those items' do
      create(:donation, organization: organization)
      expected_quantities = Array.new(items.size, 0)
      expect(subject.item_quantities_by_name_and_date(date_range)).to eq(expected_quantities)
    end
  end

  context 'when donations have line_items within the date range' do
    it 'returns correct quantities for each item' do
      donation = create(:donation, organization: organization, created_at: Date.today)
      items.each do |item|
        create(:line_item, donation: donation, item: item, quantity: rand(1..10))
      end
      expected_quantities = items.sort_by(&:name).map do |item|
        donation.line_items.where(item: item).sum(:quantity)
      end
      expect(subject.item_quantities_by_name_and_date(date_range)).to eq(expected_quantities)
    end
  end

  context 'when donations have line_items outside the date range' do
    it 'does not include quantities for those line_items' do
      donation = create(:donation, organization: organization, created_at: Date.today - 1.month)
      items.each do |item|
        create(:line_item, donation: donation, item: item, quantity: rand(1..10))
      end
      expected_quantities = Array.new(items.size, 0)
      expect(subject.item_quantities_by_name_and_date(date_range)).to eq(expected_quantities)
    end
  end
end
describe '#donation_quantity_by_date', :phoenix do
  let(:date_range) { Date.today.beginning_of_month..Date.today.end_of_month }
  let(:item_category) { ItemCategory.create(name: 'Category 1') }
  let(:item) { Item.create(name: 'Item 1', item_category: item_category) }
  let(:line_item) { LineItem.create(item: item, quantity: 5) }
  let(:donation) { Donation.create(date: Date.today, line_items: [line_item]) }

  it 'calculates donation quantity for a valid date range' do
    donation
    expect(subject.donation_quantity_by_date(date_range)).to eq(5)
  end

  context 'when item_category_id is provided' do
    let(:item_category_id) { item_category.id }

    it 'calculates donation quantity for the specified item category' do
      donation
      expect(subject.donation_quantity_by_date(date_range, item_category_id)).to eq(5)
    end
  end

  context 'when item_category_id is not provided' do
    it 'calculates donation quantity for all item categories' do
      donation
      expect(subject.donation_quantity_by_date(date_range)).to eq(5)
    end
  end

  context 'when date_range is empty' do
    let(:date_range) { nil }

    it 'returns zero donation quantity' do
      expect(subject.donation_quantity_by_date(date_range)).to eq(0)
    end
  end

  context 'when date_range is invalid' do
    let(:date_range) { 'invalid' }

    it 'handles invalid date range gracefully' do
      expect { subject.donation_quantity_by_date(date_range) }.not_to raise_error
    end
  end

  context 'when there are no donations in the date range' do
    let(:date_range) { (Date.today - 1.month).beginning_of_month..(Date.today - 1.month).end_of_month }

    it 'returns zero donation quantity' do
      expect(subject.donation_quantity_by_date(date_range)).to eq(0)
    end
  end

  context 'when there are multiple donations in the date range' do
    let(:line_item_2) { LineItem.create(item: item, quantity: 10) }
    let(:donation_2) { Donation.create(date: Date.today, line_items: [line_item_2]) }

    it 'sums up the donation quantities correctly' do
      donation
      donation_2
      expect(subject.donation_quantity_by_date(date_range)).to eq(15)
    end
  end
end
describe '#distinct_items_count_by_date', :phoenix do
  let(:product_drive) { ProductDrive.new }
  let(:date_range) { Date.today.beginning_of_month..Date.today.end_of_month }
  let(:item_category) { create(:item_category) }
  let(:item) { Item.create(name: 'Test Item', item_category: item_category) }
  let(:donation) { Donation.create(date: Date.today) }
  let(:line_item) { LineItem.create(donation: donation, item: item) }

  before do
    donation.line_items << line_item
  end

  it 'returns count of distinct items when item_category_id is not provided' do
    expect(product_drive.distinct_items_count_by_date(date_range)).to eq(1)
  end

  it 'returns count of distinct items when item_category_id is provided' do
    expect(product_drive.distinct_items_count_by_date(date_range, item_category.id)).to eq(1)
  end

  it 'returns zero for an empty date range' do
    empty_date_range = Date.today.next_month..Date.today.next_month.end_of_month
    expect(product_drive.distinct_items_count_by_date(empty_date_range)).to eq(0)
  end

  it 'returns zero when there are no donations in the date range' do
    no_donation_date_range = Date.today.last_month..Date.today.last_month.end_of_month
    expect(product_drive.distinct_items_count_by_date(no_donation_date_range)).to eq(0)
  end

  it 'returns correct count when there are multiple donations with distinct items' do
    another_item = Item.create(name: 'Another Test Item', item_category: item_category)
    another_donation = Donation.create(date: Date.today)
    another_line_item = LineItem.create(donation: another_donation, item: another_item)
    another_donation.line_items << another_line_item

    expect(product_drive.distinct_items_count_by_date(date_range)).to eq(2)
  end
end
end
