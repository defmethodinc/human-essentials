
require "rails_helper"

RSpec.describe ProductDrive do
describe '#distinct_items_count_by_date' do
  let(:organization) { create(:organization) }
  let(:item_category) { create(:item_category, organization: organization) }
  let(:item) { create(:item, organization: organization, item_category: item_category) }
  let(:date_range) { (Time.current - 1.week)..Time.current }

  let(:donation_with_items) do
    create(:donation, :with_items, organization: organization, item: item, issued_at: Time.current - 3.days)
  end

  let(:donation_without_items) do
    create(:donation, organization: organization, issued_at: Time.current - 3.days)
  end

  it 'returns distinct item count when item_category_id is provided and there are matching items' do
    donation_with_items
    expect(ProductDrive.new.distinct_items_count_by_date(date_range, item_category.id)).to eq(1)
  end

  it 'returns zero when item_category_id is provided but there are no matching items' do
    donation_without_items
    expect(ProductDrive.new.distinct_items_count_by_date(date_range, item_category.id)).to eq(0)
  end

  it 'returns distinct item count when item_category_id is not provided' do
    donation_with_items
    expect(ProductDrive.new.distinct_items_count_by_date(date_range)).to eq(1)
  end

  it 'returns zero when date_range has no donations' do
    expect(ProductDrive.new.distinct_items_count_by_date(date_range)).to eq(0)
  end

  it 'returns zero when date_range has donations but no line items' do
    donation_without_items
    expect(ProductDrive.new.distinct_items_count_by_date(date_range)).to eq(0)
  end

  it 'returns distinct item count when date_range has donations with line items' do
    donation_with_items
    expect(ProductDrive.new.distinct_items_count_by_date(date_range)).to eq(1)
  end
end
describe "#donation_quantity" do
    let(:product_drive) { create(:product_drive) }
    let(:donation) { create(:donation, product_drive: product_drive) }
    let(:donation_with_items) { create(:donation, :with_items, item_quantity: 5, product_drive: product_drive) }
    let(:donation_with_zero_items) { create(:donation, :with_items, item_quantity: 1, product_drive: product_drive) }
    let(:multiple_donations) { create_list(:donation, 3, :with_items, item_quantity: 5, product_drive: product_drive) }

    it "returns 0 when there are no donations" do
      expect(product_drive.donation_quantity).to eq(0)
    end

    context "when there are donations but no line items" do
      before { donation }

      it "returns 0" do
        expect(product_drive.donation_quantity).to eq(0)
      end
    end

    context "when line items have zero quantity" do
      before do
        donation_with_zero_items.line_items.each { |li| li.update(quantity: 0) }
      end

      it "returns 0" do
        expect(product_drive.donation_quantity).to eq(0)
      end
    end

    context "when there are donations with positive quantities" do
      before { donation_with_items }

      it "returns the correct sum" do
        expect(product_drive.donation_quantity).to eq(5)
      end
    end

    context "when there are multiple donations with line items" do
      before { multiple_donations }

      it "returns the correct sum" do
        expect(product_drive.donation_quantity).to eq(15)
      end
    end
  end
describe "#donation_quantity_by_date" do
    let(:organization) { create(:organization) }
    let(:item_category) { create(:item_category, organization: organization) }
    let(:item) { create(:item, organization: organization, item_category: item_category) }
    let(:donation_site) { create(:donation_site, organization: organization) }
    let!(:donation_with_items) { create(:donation, :with_items, organization: organization, donation_site: donation_site, issued_at: Time.current, item_quantity: 10, item: item) }
    let!(:donation_without_items) { create(:donation, organization: organization, donation_site: donation_site, issued_at: Time.current) }

    it "returns the correct sum when item_category_id is provided and date_range is valid" do
      expect(subject.donation_quantity_by_date(Time.current.all_day, item_category.id)).to eq(10)
    end

    it "returns the correct sum when item_category_id is not provided and date_range is valid" do
      expect(subject.donation_quantity_by_date(Time.current.all_day)).to eq(10)
    end

    it "returns zero when item_category_id is provided but no donations match the criteria" do
      donation_without_items
      expect(subject.donation_quantity_by_date(Time.current.all_day, item_category.id)).to eq(0)
    end

    it "returns zero when item_category_id is not provided but no donations match the criteria" do
      donation_without_items
      expect(subject.donation_quantity_by_date(Time.current.all_day)).to eq(0)
    end

    it "returns zero for an empty or invalid date_range" do
      expect(subject.donation_quantity_by_date(nil)).to eq(0)
    end

    it "calculates the sum correctly for multiple donations within the date range" do
      create(:donation, :with_items, organization: organization, donation_site: donation_site, issued_at: Time.current, item_quantity: 5, item: item)
      expect(subject.donation_quantity_by_date(Time.current.all_day)).to eq(15)
    end
  end
describe "#in_kind_value" do
  let(:product_drive) { build(:product_drive, donations: donations) }

  context "when there are no donations" do
    let(:donations) { [] }

    it "returns 0" do
      expect(product_drive.in_kind_value).to eq(0)
    end
  end

  context "when there are donations with positive values" do
    let(:donations) { build_list(:donation, 3, :with_items, item_quantity: 1, item: build(:item, value_in_cents: 100)) }

    it "returns the sum of value_per_itemizable for all donations" do
      expect(product_drive.in_kind_value).to eq(300)
    end
  end

  context "when there are donations with zero value" do
    let(:donations) { build_list(:donation, 3, :with_items, item_quantity: 0, item: build(:item, value_in_cents: 0)) }

    it "returns 0 for donations with zero value" do
      expect(product_drive.in_kind_value).to eq(0)
    end
  end

  context "when there are donations with negative values" do
    let(:donations) { build_list(:donation, 3, :with_items, item_quantity: 1, item: build(:item, value_in_cents: -50)) }

    it "returns the sum of negative values for donations" do
      expect(product_drive.in_kind_value).to eq(-150)
    end
  end
end
describe "#item_quantities_by_name_and_date" do
    let(:organization) { create(:organization) }
    let(:product_drive) { create(:product_drive, organization: organization) }
    let(:item1) { create(:item, organization: organization) }
    let(:item2) { create(:item, organization: organization) }
    let(:donation1) { create(:donation, :with_items, organization: organization, product_drive: product_drive, issued_at: 2.days.ago, item: item1, item_quantity: 5) }
    let(:donation2) { create(:donation, :with_items, organization: organization, product_drive: product_drive, issued_at: 1.day.ago, item: item2, item_quantity: 10) }
    let(:empty_donation) { create(:donation, organization: organization, product_drive: product_drive, issued_at: 1.day.ago) }

    subject { product_drive.item_quantities_by_name_and_date(date_range) }

    context "when there are donations within the date range" do
      let(:date_range) { 3.days.ago..Date.today }

      it "returns quantities for donations within the date range" do
        expect(subject).to eq([5, 10])
      end
    end

    context "when there are no donations within the date range" do
      let(:date_range) { 5.days.ago..4.days.ago }

      it "returns zero quantities" do
        expect(subject).to eq([0, 0])
      end
    end

    context "when there are no line items associated with donations" do
      let(:date_range) { 3.days.ago..Date.today }
      before { empty_donation }

      it "returns zero quantities" do
        expect(subject).to eq([0, 0])
      end
    end

    context "when the organization has no items" do
      let(:organization) { create(:organization) }
      let(:product_drive) { create(:product_drive, organization: organization) }
      let(:date_range) { 3.days.ago..Date.today }

      it "returns zero quantities" do
        expect(subject).to eq([])
      end
    end

    context "when all quantities are zero" do
      let(:date_range) { 3.days.ago..Date.today }
      before do
        donation1.line_items.update_all(quantity: 0)
        donation2.line_items.update_all(quantity: 0)
      end

      it "returns zero quantities" do
        expect(subject).to eq([0, 0])
      end
    end

    context "when handling overlapping date ranges" do
      let(:date_range) { 2.days.ago..1.day.ago }

      it "returns correct quantities" do
        expect(subject).to eq([5, 10])
      end
    end

    context "when handling non-overlapping date ranges" do
      let(:date_range) { 3.days.ago..2.days.ago }

      it "returns correct quantities" do
        expect(subject).to eq([5, 0])
      end
    end
  end
describe '.search_date_range', :phoenix do
  let(:valid_date_range) { "2023-01-01 - 2023-12-31" }
  let(:invalid_date_range) { "2023-12-31 - 2023-01-01" }
  let(:single_date) { "2023-01-01" }
  let(:empty_string) { "" }
  let(:nil_input) { nil }
  let(:extra_spaces) { " 2023-01-01 - 2023-12-31 " }

  context 'with valid date range input' do
    it 'parses start date correctly' do
      result = ProductDrive.search_date_range(valid_date_range)
      expect(result[:start_date]).to eq('2023-01-01')
    end

    it 'parses end date correctly' do
      result = ProductDrive.search_date_range(valid_date_range)
      expect(result[:end_date]).to eq('2023-12-31')
    end
  end

  context 'with invalid date range input' do
    it 'parses start date correctly' do
      result = ProductDrive.search_date_range(invalid_date_range)
      expect(result[:start_date]).to eq('2023-12-31')
    end

    it 'parses end date correctly' do
      result = ProductDrive.search_date_range(invalid_date_range)
      expect(result[:end_date]).to eq('2023-01-01')
    end
  end

  context 'with single date input' do
    it 'sets start date to the single date' do
      result = ProductDrive.search_date_range(single_date)
      expect(result[:start_date]).to eq('2023-01-01')
    end

    it 'sets end date to the single date' do
      result = ProductDrive.search_date_range(single_date)
      expect(result[:end_date]).to eq('2023-01-01')
    end
  end

  context 'with empty string input' do
    it 'returns nil for start date' do
      result = ProductDrive.search_date_range(empty_string)
      expect(result[:start_date]).to be_nil
    end

    it 'returns nil for end date' do
      result = ProductDrive.search_date_range(empty_string)
      expect(result[:end_date]).to be_nil
    end
  end

  context 'with nil input' do
    it 'returns nil for start date' do
      result = ProductDrive.search_date_range(nil_input)
      expect(result[:start_date]).to be_nil
    end

    it 'returns nil for end date' do
      result = ProductDrive.search_date_range(nil_input)
      expect(result[:end_date]).to be_nil
    end
  end

  context 'with input having extra spaces' do
    it 'trims spaces and parses start date correctly' do
      result = ProductDrive.search_date_range(extra_spaces)
      expect(result[:start_date]).to eq('2023-01-01')
    end

    it 'trims spaces and parses end date correctly' do
      result = ProductDrive.search_date_range(extra_spaces)
      expect(result[:end_date]).to eq('2023-12-31')
    end
  end
end
describe "#donation_quantity_by_date" do
    let(:organization) { create(:organization) }
    let(:item_category) { create(:item_category, organization: organization) }
    let(:item) { create(:item, organization: organization, item_category: item_category) }
    let(:donation_site) { create(:donation_site, organization: organization) }
    let!(:donation_with_items) { create(:donation, :with_items, organization: organization, donation_site: donation_site, issued_at: Time.current, item_quantity: 10, item: item) }
    let!(:donation_without_items) { create(:donation, organization: organization, donation_site: donation_site, issued_at: Time.current) }

    it "returns the correct sum when item_category_id is provided and date_range is valid" do
      expect(subject.donation_quantity_by_date(Time.current.all_day, item_category.id)).to eq(10)
    end

    it "returns the correct sum when item_category_id is not provided and date_range is valid" do
      expect(subject.donation_quantity_by_date(Time.current.all_day)).to eq(10)
    end

    it "returns zero when item_category_id is provided but no donations match the criteria" do
      donation_without_items
      expect(subject.donation_quantity_by_date(Time.current.all_day, item_category.id)).to eq(0)
    end

    it "returns zero when item_category_id is not provided but no donations match the criteria" do
      donation_without_items
      expect(subject.donation_quantity_by_date(Time.current.all_day)).to eq(0)
    end

    it "returns zero for an empty or invalid date_range" do
      expect(subject.donation_quantity_by_date(nil)).to eq(0)
    end

    it "calculates the sum correctly for multiple donations within the date range" do
      create(:donation, :with_items, organization: organization, donation_site: donation_site, issued_at: Time.current, item_quantity: 5, item: item)
      expect(subject.donation_quantity_by_date(Time.current.all_day)).to eq(15)
    end
  end
describe "#in_kind_value" do
  let(:product_drive) { build(:product_drive, donations: donations) }

  context "when there are no donations" do
    let(:donations) { [] }

    it "returns 0" do
      expect(product_drive.in_kind_value).to eq(0)
    end
  end

  context "when there are donations with positive values" do
    let(:donations) { build_list(:donation, 3, :with_items, item_quantity: 1, item: build(:item, value_in_cents: 100)) }

    it "returns the sum of value_per_itemizable for all donations" do
      expect(product_drive.in_kind_value).to eq(300)
    end
  end

  context "when there are donations with zero value" do
    let(:donations) { build_list(:donation, 3, :with_items, item_quantity: 0, item: build(:item, value_in_cents: 0)) }

    it "returns 0 for donations with zero value" do
      expect(product_drive.in_kind_value).to eq(0)
    end
  end

  context "when there are donations with negative values" do
    let(:donations) { build_list(:donation, 3, :with_items, item_quantity: 1, item: build(:item, value_in_cents: -50)) }

    it "returns the sum of negative values for donations" do
      expect(product_drive.in_kind_value).to eq(-150)
    end
  end
end
describe "#donation_quantity" do
    let(:product_drive) { create(:product_drive) }
    let(:donation) { create(:donation, product_drive: product_drive) }
    let(:donation_with_items) { create(:donation, :with_items, item_quantity: 5, product_drive: product_drive) }
    let(:donation_with_zero_items) { create(:donation, :with_items, item_quantity: 1, product_drive: product_drive) }
    let(:multiple_donations) { create_list(:donation, 3, :with_items, item_quantity: 5, product_drive: product_drive) }

    it "returns 0 when there are no donations" do
      expect(product_drive.donation_quantity).to eq(0)
    end

    context "when there are donations but no line items" do
      before { donation }

      it "returns 0" do
        expect(product_drive.donation_quantity).to eq(0)
      end
    end

    context "when line items have zero quantity" do
      before do
        donation_with_zero_items.line_items.each { |li| li.update(quantity: 0) }
      end

      it "returns 0" do
        expect(product_drive.donation_quantity).to eq(0)
      end
    end

    context "when there are donations with positive quantities" do
      before { donation_with_items }

      it "returns the correct sum" do
        expect(product_drive.donation_quantity).to eq(5)
      end
    end

    context "when there are multiple donations with line items" do
      before { multiple_donations }

      it "returns the correct sum" do
        expect(product_drive.donation_quantity).to eq(15)
      end
    end
  end
describe '#distinct_items_count_by_date' do
  let(:organization) { create(:organization) }
  let(:item_category) { create(:item_category, organization: organization) }
  let(:item) { create(:item, organization: organization, item_category: item_category) }
  let(:date_range) { (Time.current - 1.week)..Time.current }

  let(:donation_with_items) do
    create(:donation, :with_items, organization: organization, item: item, issued_at: Time.current - 3.days)
  end

  let(:donation_without_items) do
    create(:donation, organization: organization, issued_at: Time.current - 3.days)
  end

  it 'returns distinct item count when item_category_id is provided and there are matching items' do
    donation_with_items
    expect(ProductDrive.new.distinct_items_count_by_date(date_range, item_category.id)).to eq(1)
  end

  it 'returns zero when item_category_id is provided but there are no matching items' do
    donation_without_items
    expect(ProductDrive.new.distinct_items_count_by_date(date_range, item_category.id)).to eq(0)
  end

  it 'returns distinct item count when item_category_id is not provided' do
    donation_with_items
    expect(ProductDrive.new.distinct_items_count_by_date(date_range)).to eq(1)
  end

  it 'returns zero when date_range has no donations' do
    expect(ProductDrive.new.distinct_items_count_by_date(date_range)).to eq(0)
  end

  it 'returns zero when date_range has donations but no line items' do
    donation_without_items
    expect(ProductDrive.new.distinct_items_count_by_date(date_range)).to eq(0)
  end

  it 'returns distinct item count when date_range has donations with line items' do
    donation_with_items
    expect(ProductDrive.new.distinct_items_count_by_date(date_range)).to eq(1)
  end
end
describe '.search_date_range', :phoenix do
  let(:valid_date_range) { "2023-01-01 - 2023-12-31" }
  let(:invalid_date_range) { "2023-12-31 - 2023-01-01" }
  let(:single_date) { "2023-01-01" }
  let(:empty_string) { "" }
  let(:nil_input) { nil }
  let(:extra_spaces) { " 2023-01-01 - 2023-12-31 " }

  context 'with valid date range input' do
    it 'parses start date correctly' do
      result = ProductDrive.search_date_range(valid_date_range)
      expect(result[:start_date]).to eq('2023-01-01')
    end

    it 'parses end date correctly' do
      result = ProductDrive.search_date_range(valid_date_range)
      expect(result[:end_date]).to eq('2023-12-31')
    end
  end

  context 'with invalid date range input' do
    it 'parses start date correctly' do
      result = ProductDrive.search_date_range(invalid_date_range)
      expect(result[:start_date]).to eq('2023-12-31')
    end

    it 'parses end date correctly' do
      result = ProductDrive.search_date_range(invalid_date_range)
      expect(result[:end_date]).to eq('2023-01-01')
    end
  end

  context 'with single date input' do
    it 'sets start date to the single date' do
      result = ProductDrive.search_date_range(single_date)
      expect(result[:start_date]).to eq('2023-01-01')
    end

    it 'sets end date to the single date' do
      result = ProductDrive.search_date_range(single_date)
      expect(result[:end_date]).to eq('2023-01-01')
    end
  end

  context 'with empty string input' do
    it 'returns nil for start date' do
      result = ProductDrive.search_date_range(empty_string)
      expect(result[:start_date]).to be_nil
    end

    it 'returns nil for end date' do
      result = ProductDrive.search_date_range(empty_string)
      expect(result[:end_date]).to be_nil
    end
  end

  context 'with nil input' do
    it 'returns nil for start date' do
      result = ProductDrive.search_date_range(nil_input)
      expect(result[:start_date]).to be_nil
    end

    it 'returns nil for end date' do
      result = ProductDrive.search_date_range(nil_input)
      expect(result[:end_date]).to be_nil
    end
  end

  context 'with input having extra spaces' do
    it 'trims spaces and parses start date correctly' do
      result = ProductDrive.search_date_range(extra_spaces)
      expect(result[:start_date]).to eq('2023-01-01')
    end

    it 'trims spaces and parses end date correctly' do
      result = ProductDrive.search_date_range(extra_spaces)
      expect(result[:end_date]).to eq('2023-12-31')
    end
  end
end
describe '#distinct_items_count', :phoenix do
  let(:product_drive) { create(:product_drive) }

  context 'when there are no donations' do
    it 'returns 0' do
      expect(product_drive.distinct_items_count).to eq(0)
    end
  end

  context 'when there are donations but no line items' do
    let!(:donations) { create_list(:donation, 3, product_drive: product_drive) }

    it 'returns 0' do
      expect(product_drive.distinct_items_count).to eq(0)
    end
  end

  context 'when there are donations with distinct item IDs' do
    let!(:donations) do
      create_list(:donation, 3, :with_items, product_drive: product_drive) do |donation, index|
        donation.line_items.first.update(item: create(:item, name: "Item \\#{index}"))
      end
    end

    it 'returns the correct count of distinct items' do
      expect(product_drive.distinct_items_count).to eq(3)
    end
  end

  context 'when there are donations with duplicate item IDs' do
    let(:item) { create(:item) }
    let!(:donations) do
      create_list(:donation, 3, :with_items, product_drive: product_drive, item: item)
    end

    it 'returns the count of unique items' do
      expect(product_drive.distinct_items_count).to eq(1)
    end
  end

  context 'when there are multiple donations with overlapping line items' do
    let(:item1) { create(:item, name: 'Item 1') }
    let(:item2) { create(:item, name: 'Item 2') }
    let!(:donation1) { create(:donation, :with_items, product_drive: product_drive, item: item1) }
    let!(:donation2) { create(:donation, :with_items, product_drive: product_drive, item: item2) }
    let!(:donation3) { create(:donation, :with_items, product_drive: product_drive, item: item1) }

    it 'returns the count of distinct items considering overlaps' do
      expect(product_drive.distinct_items_count).to eq(2)
    end
  end
end
describe "#item_quantities_by_name_and_date" do
    let(:organization) { create(:organization) }
    let(:product_drive) { create(:product_drive, organization: organization) }
    let(:item1) { create(:item, organization: organization) }
    let(:item2) { create(:item, organization: organization) }
    let(:donation1) { create(:donation, :with_items, organization: organization, product_drive: product_drive, issued_at: 2.days.ago, item: item1, item_quantity: 5) }
    let(:donation2) { create(:donation, :with_items, organization: organization, product_drive: product_drive, issued_at: 1.day.ago, item: item2, item_quantity: 10) }
    let(:empty_donation) { create(:donation, organization: organization, product_drive: product_drive, issued_at: 1.day.ago) }

    subject { product_drive.item_quantities_by_name_and_date(date_range) }

    context "when there are donations within the date range" do
      let(:date_range) { 3.days.ago..Date.today }

      it "returns quantities for donations within the date range" do
        expect(subject).to eq([5, 10])
      end
    end

    context "when there are no donations within the date range" do
      let(:date_range) { 5.days.ago..4.days.ago }

      it "returns zero quantities" do
        expect(subject).to eq([0, 0])
      end
    end

    context "when there are no line items associated with donations" do
      let(:date_range) { 3.days.ago..Date.today }
      before { empty_donation }

      it "returns zero quantities" do
        expect(subject).to eq([0, 0])
      end
    end

    context "when the organization has no items" do
      let(:organization) { create(:organization) }
      let(:product_drive) { create(:product_drive, organization: organization) }
      let(:date_range) { 3.days.ago..Date.today }

      it "returns zero quantities" do
        expect(subject).to eq([])
      end
    end

    context "when all quantities are zero" do
      let(:date_range) { 3.days.ago..Date.today }
      before do
        donation1.line_items.update_all(quantity: 0)
        donation2.line_items.update_all(quantity: 0)
      end

      it "returns zero quantities" do
        expect(subject).to eq([0, 0])
      end
    end

    context "when handling overlapping date ranges" do
      let(:date_range) { 2.days.ago..1.day.ago }

      it "returns correct quantities" do
        expect(subject).to eq([5, 10])
      end
    end

    context "when handling non-overlapping date ranges" do
      let(:date_range) { 3.days.ago..2.days.ago }

      it "returns correct quantities" do
        expect(subject).to eq([5, 0])
      end
    end
  end
describe '#end_date_is_bigger_of_end_date', :phoenix do
  let(:product_drive) { build(:product_drive, start_date: start_date, end_date: end_date) }

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
    let(:end_date) { Time.current }

    it 'does not add errors to end_date' do
      product_drive.valid?
      expect(product_drive.errors[:end_date]).to be_empty
    end
  end

  context 'when end_date is nil and start_date is not nil' do
    let(:start_date) { Time.current }
    let(:end_date) { nil }

    it 'does not add errors to end_date' do
      product_drive.valid?
      expect(product_drive.errors[:end_date]).to be_empty
    end
  end

  context 'when end_date is greater than start_date' do
    let(:start_date) { Time.current }
    let(:end_date) { Time.current + 1.day }

    it 'does not add errors to end_date' do
      product_drive.valid?
      expect(product_drive.errors[:end_date]).to be_empty
    end
  end

  context 'when end_date is less than start_date' do
    let(:start_date) { Time.current }
    let(:end_date) { Time.current - 1.day }

    it 'adds an error to end_date indicating it must be after the start date' do
      product_drive.valid?
      expect(product_drive.errors[:end_date]).to include('must be after the start date')
    end
  end
end
describe '#donation_source_view', :phoenix do
  let(:product_drive) { build(:product_drive, name: drive_name) }

  context 'with a normal string name' do
    let(:drive_name) { 'Test Drive' }

    it 'returns the name with (product drive)' do
      expect(product_drive.donation_source_view).to eq('Test Drive (product drive)')
    end
  end

  context 'with an empty name' do
    let(:drive_name) { '' }

    it 'returns (product drive)' do
      expect(product_drive.donation_source_view).to eq(' (product drive)')
    end
  end

  context 'with a nil name' do
    let(:drive_name) { nil }

    it 'handles nil name gracefully' do
      expect(product_drive.donation_source_view).to eq(' (product drive)')
    end
  end

  context 'with a name containing special characters' do
    let(:drive_name) { 'Special!@#' }

    it 'returns the name with special characters and (product drive)' do
      expect(product_drive.donation_source_view).to eq('Special!@# (product drive)')
    end
  end
end
end
