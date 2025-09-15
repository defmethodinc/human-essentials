
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
describe "#donation_quantity", :phoenix do
  let(:product_drive) { ProductDrive.new }

  it "returns zero when there are no donations" do
    expect(product_drive.donation_quantity).to eq(0)
  end

  describe "when donations exist" do
    context "and donations have no line items" do
      before do
        Donation.create(product_drive: product_drive)
      end

      it "returns zero" do
        expect(product_drive.donation_quantity).to eq(0)
      end
    end

    context "and donations have line items" do
      before do
        donation = Donation.create(product_drive: product_drive)
        LineItem.create(donation: donation, quantity: 5)
      end

      it "returns the sum of quantities" do
        expect(product_drive.donation_quantity).to eq(5)
      end
    end

    context "and multiple donations with line items exist" do
      before do
        donation1 = Donation.create(product_drive: product_drive)
        donation2 = Donation.create(product_drive: product_drive)
        LineItem.create(donation: donation1, quantity: 3)
        LineItem.create(donation: donation2, quantity: 7)
      end

      it "returns the sum of all quantities" do
        expect(product_drive.donation_quantity).to eq(10)
      end
    end
  end

  describe "edge cases" do
    context "when line items have zero quantity" do
      before do
        donation = Donation.create(product_drive: product_drive)
        LineItem.create(donation: donation, quantity: 0)
      end

      it "returns zero" do
        expect(product_drive.donation_quantity).to eq(0)
      end
    end

    context "when line items have negative quantities" do
      before do
        donation = Donation.create(product_drive: product_drive)
        LineItem.create(donation: donation, quantity: -2)
      end

      it "handles negative quantities" do
        expect(product_drive.donation_quantity).to eq(-2)
      end
    end
  end
end
describe '#distinct_items_count', :phoenix do
  let(:product_drive) { ProductDrive.new }

  it 'returns 0 when there are no donations' do
    expect(product_drive.distinct_items_count).to eq(0)
  end

  context 'when donations have no line items' do
    let!(:donation) { Donation.create }
    it 'returns 0' do
      expect(product_drive.distinct_items_count).to eq(0)
    end
  end

  context 'when counting distinct item_ids across line items' do
    let!(:item1) { Item.create }
    let!(:item2) { Item.create }
    let!(:donation) { Donation.create }
    let!(:line_item1) { LineItem.create(donation: donation, item: item1) }
    let!(:line_item2) { LineItem.create(donation: donation, item: item2) }
    it 'returns the correct count of distinct items' do
      expect(product_drive.distinct_items_count).to eq(2)
    end
  end

  context 'when multiple line items have the same item_id' do
    let!(:item) { Item.create }
    let!(:donation) { Donation.create }
    let!(:line_item1) { LineItem.create(donation: donation, item: item) }
    let!(:line_item2) { LineItem.create(donation: donation, item: item) }
    it 'returns 1 for identical item_ids' do
      expect(product_drive.distinct_items_count).to eq(1)
    end
  end

  context 'when line items have different item_ids' do
    let!(:item1) { Item.create }
    let!(:item2) { Item.create }
    let!(:donation) { Donation.create }
    let!(:line_item1) { LineItem.create(donation: donation, item: item1) }
    let!(:line_item2) { LineItem.create(donation: donation, item: item2) }
    it 'returns the correct count for different item_ids' do
      expect(product_drive.distinct_items_count).to eq(2)
    end
  end
end
describe '#in_kind_value', :phoenix do
  let(:product_drive) { ProductDrive.create }

  context 'when there are no donations' do
    it 'returns 0' do
      expect(product_drive.in_kind_value).to eq(0)
    end
  end

  context 'when there is a single donation' do
    let!(:donation) { Donation.create(value_per_itemizable: 100, product_drive: product_drive) }

    it 'returns the value of the donation' do
      expect(product_drive.in_kind_value).to eq(100)
    end
  end

  context 'when there are multiple donations' do
    let!(:donation1) { Donation.create(value_per_itemizable: 100, product_drive: product_drive) }
    let!(:donation2) { Donation.create(value_per_itemizable: 200, product_drive: product_drive) }

    it 'returns the sum of the donation values' do
      expect(product_drive.in_kind_value).to eq(300)
    end
  end

  context 'when donations have nil value_per_itemizable' do
    let!(:donation) { Donation.create(value_per_itemizable: nil, product_drive: product_drive) }

    it 'treats nil values as 0' do
      expect(product_drive.in_kind_value).to eq(0)
    end
  end

  context 'when donations have zero value' do
    let!(:donation1) { Donation.create(value_per_itemizable: 0, product_drive: product_drive) }
    let!(:donation2) { Donation.create(value_per_itemizable: 100, product_drive: product_drive) }

    it 'correctly sums zero and non-zero values' do
      expect(product_drive.in_kind_value).to eq(100)
    end
  end
end
describe '#donation_source_view', :phoenix do
  let(:product_drive) { ProductDrive.new(name: name) }

  context 'when name is a normal string' do
    let(:name) { 'Normal Name' }

    it 'returns the name with product drive suffix for a normal name' do
      expect(product_drive.donation_source_view).to eq('Normal Name (product drive)')
    end
  end

  context 'when name is an empty string' do
    let(:name) { '' }

    it 'returns the product drive suffix when name is an empty string' do
      expect(product_drive.donation_source_view).to eq(' (product drive)')
    end
  end

  context 'when name is nil' do
    let(:name) { nil }

    it 'handles nil name gracefully' do
      expect(product_drive.donation_source_view).to eq(' (product drive)')
    end
  end
end
describe '.search_date_range', :phoenix do
  let(:valid_dates) { '2023-01-01 - 2023-12-31' }
  let(:invalid_date_format) { '2023/01/01 - 2023/12/31' }
  let(:single_date) { '2023-01-01' }
  let(:empty_string) { '' }
  let(:non_date_string) { 'not-a-date' }
  let(:whitespace_input) { '   ' }
  let(:reversed_date_range) { '2023-12-31 - 2023-01-01' }

  it 'returns correct hash for valid date range' do
    result = ProductDrive.search_date_range(valid_dates)
    expect(result).to eq({ start_date: '2023-01-01', end_date: '2023-12-31' })
  end

  it 'raises ArgumentError for invalid date format' do
    expect { ProductDrive.search_date_range(invalid_date_format) }.to raise_error(ArgumentError)
  end

  it 'raises ArgumentError for single date input' do
    expect { ProductDrive.search_date_range(single_date) }.to raise_error(ArgumentError)
  end

  it 'raises ArgumentError for empty string input' do
    expect { ProductDrive.search_date_range(empty_string) }.to raise_error(ArgumentError)
  end

  it 'raises ArgumentError for non-date string input' do
    expect { ProductDrive.search_date_range(non_date_string) }.to raise_error(ArgumentError)
  end

  it 'raises ArgumentError for whitespace input' do
    expect { ProductDrive.search_date_range(whitespace_input) }.to raise_error(ArgumentError)
  end

  it 'returns correct hash for reversed date range' do
    result = ProductDrive.search_date_range(reversed_date_range)
    expect(result).to eq({ start_date: '2023-12-31', end_date: '2023-01-01' })
  end
end
describe "#item_quantities_by_name_and_date", :phoenix do
  let(:organization) { Organization.create(name: "Test Organization") }
  let(:item1) { organization.items.create(name: "Item 1") }
  let(:item2) { organization.items.create(name: "Item 2") }
  let(:donation1) { Donation.create(organization: organization, created_at: Date.today) }
  let(:donation2) { Donation.create(organization: organization, created_at: Date.today) }
  let(:line_item1) { LineItem.create(donation: donation1, item: item1, quantity: 5) }
  let(:line_item2) { LineItem.create(donation: donation2, item: item2, quantity: 10) }

  it "returns zero quantities when there are no donations in the date range" do
    result = organization.item_quantities_by_name_and_date(Date.tomorrow..Date.tomorrow)
    expect(result).to eq([0, 0])
  end

  it "returns zero quantities when there are donations but no line items" do
    donation1
    donation2
    result = organization.item_quantities_by_name_and_date(Date.today..Date.today)
    expect(result).to eq([0, 0])
  end

  it "returns zero quantities when there are line items but no matching items in the organization" do
    other_organization = Organization.create(name: "Other Organization")
    other_item = other_organization.items.create(name: "Other Item")
    LineItem.create(donation: donation1, item: other_item, quantity: 5)
    result = organization.item_quantities_by_name_and_date(Date.today..Date.today)
    expect(result).to eq([0, 0])
  end

  it "sums quantities correctly when there are matching items" do
    line_item1
    line_item2
    result = organization.item_quantities_by_name_and_date(Date.today..Date.today)
    expect(result).to eq([5, 10])
  end

  it "returns zero quantities for an empty date range" do
    result = organization.item_quantities_by_name_and_date(nil)
    expect(result).to eq([0, 0])
  end

  it "raises an error for an invalid date range" do
    expect { organization.item_quantities_by_name_and_date('invalid') }.to raise_error(ArgumentError)
  end
end
describe "#donation_quantity_by_date", :phoenix do
  let(:date_range) { Date.today.beginning_of_month..Date.today.end_of_month }
  let(:item_category) { ItemCategory.create(name: "Category 1") }
  let(:item) { Item.create(name: "Item 1", item_category: item_category) }
  let(:line_item) { LineItem.create(item: item, quantity: 10) }
  let(:donation) { Donation.create(date: Date.today, line_items: [line_item]) }

  context "when calculating donation quantity for a valid date range" do
    it "without item category" do
      donation
      expect(subject.donation_quantity_by_date(date_range)).to eq(10)
    end

    it "with a specific item category" do
      donation
      expect(subject.donation_quantity_by_date(date_range, item_category.id)).to eq(10)
    end
  end

  context "when handling edge cases" do
    it "with an empty date range" do
      expect(subject.donation_quantity_by_date(nil)).to eq(0)
    end

    it "with an invalid date range" do
      expect(subject.donation_quantity_by_date('invalid')).to eq(0)
    end

    it "when there are no donations in the date range" do
      expect(subject.donation_quantity_by_date(date_range)).to eq(0)
    end

    it "when there are multiple donations in the date range" do
      donation
      Donation.create(date: Date.today, line_items: [line_item])
      expect(subject.donation_quantity_by_date(date_range)).to eq(20)
    end

    it "with edge case dates where start date equals end date" do
      edge_date = Date.today
      donation.update(date: edge_date)
      expect(subject.donation_quantity_by_date(edge_date..edge_date)).to eq(10)
    end
  end
end
describe "#distinct_items_count_by_date", :phoenix do
  let(:date_range) { Date.today.beginning_of_month..Date.today.end_of_month }
  let(:donation) { Donation.create(date: Date.today) }
  let(:item_category) { ItemCategory.create(name: 'Category 1') }
  let(:item) { Item.create(name: 'Item 1', item_category: item_category) }
  let(:line_item) { LineItem.create(donation: donation, item: item) }

  context "when item_category_id is nil" do
    it "returns distinct item count" do
      donation
      line_item
      expect(ProductDrive.new.distinct_items_count_by_date(date_range)).to eq(1)
    end
  end

  context "when item_category_id is present" do
    it "returns distinct item count" do
      donation
      line_item
      expect(ProductDrive.new.distinct_items_count_by_date(date_range, item_category.id)).to eq(1)
    end
  end

  context "when there are no donations in the date range" do
    it "returns zero" do
      expect(ProductDrive.new.distinct_items_count_by_date(date_range)).to eq(0)
    end
  end

  context "when there are donations but no line items" do
    it "returns zero" do
      donation
      expect(ProductDrive.new.distinct_items_count_by_date(date_range)).to eq(0)
    end
  end

  context "when there are donations with line items but no distinct items" do
    it "returns correct distinct count" do
      donation
      LineItem.create(donation: donation, item: item)
      LineItem.create(donation: donation, item: item)
      expect(ProductDrive.new.distinct_items_count_by_date(date_range)).to eq(1)
    end
  end
end
end
