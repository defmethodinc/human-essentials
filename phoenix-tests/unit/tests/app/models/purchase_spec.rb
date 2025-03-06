
require "rails_helper"

RSpec.describe Purchase do
describe '#storage_view', :phoenix do
  let(:storage_location) { build(:storage_location, name: 'Main Warehouse') }
  let(:purchase_with_location) { build(:purchase, storage_location: storage_location) }
  let(:purchase_without_location) { build(:purchase, storage_location: nil) }

  it 'returns "N/A" when storage_location is nil' do
    expect(purchase_without_location.storage_view).to eq('N/A')
  end

  it 'returns the name of the storage_location when it is not nil' do
    expect(purchase_with_location.storage_view).to eq('Main Warehouse')
  end
end
describe "#purchased_from_view", :phoenix do
  let(:vendor) { build(:vendor, business_name: "Awesome Business") }
  let(:purchase_with_vendor) { build(:purchase, vendor: vendor) }
  let(:purchase_without_vendor) { build(:purchase, vendor: nil, purchased_from: "Google") }

  it "returns purchased_from when vendor is nil" do
    purchase = purchase_without_vendor
    expect(purchase.purchased_from_view).to eq("Google")
  end

  it "returns vendor's business_name when vendor is not nil" do
    purchase = purchase_with_vendor
    expect(purchase.purchased_from_view).to eq("Awesome Business")
  end
end
describe '#amount_spent_in_dollars', :phoenix do
  let(:purchase) { build(:purchase, amount_spent_in_cents: amount_spent_in_cents) }

  it 'converts amount spent to dollars as a float' do
    let(:amount_spent_in_cents) { 1234 }
    expect(purchase.amount_spent_in_dollars).to eq(12.34)
  end

  describe 'when amount_spent is zero' do
    let(:amount_spent_in_cents) { 0 }

    it 'returns 0.0' do
      expect(purchase.amount_spent_in_dollars).to eq(0.0)
    end
  end

  describe 'when amount_spent is negative' do
    let(:amount_spent_in_cents) { -100 }

    it 'returns negative dollar amount' do
      expect(purchase.amount_spent_in_dollars).to eq(-1.0)
    end
  end

  # Assuming currency conversion logic is handled elsewhere, this test might be redundant
  # If conversion logic is part of this method, ensure to test it separately
end
describe '#remove', :phoenix do
  let(:purchase) { create(:purchase, :with_items, item_quantity: 1) }
  let(:line_item) { purchase.line_items.first }
  let(:non_existent_id) { -1 }

  it 'removes the line item when the item is an ID and exists' do
    purchase.remove(line_item.item_id)
    expect(purchase.line_items).to be_empty
  end

  it 'does nothing when the item is an ID and does not exist' do
    purchase.remove(non_existent_id)
    expect(purchase.line_items.count).to eq(1)
  end

  it 'removes the line item when the item is an object and exists' do
    purchase.remove(line_item)
    expect(purchase.line_items).to be_empty
  end

  it 'does nothing when the item is an object and does not exist' do
    non_existent_item = build(:item, id: non_existent_id)
    purchase.remove(non_existent_item)
    expect(purchase.line_items.count).to eq(1)
  end

  describe 'when item is nil or invalid' do
    it 'does not raise an error for nil item' do
      expect { purchase.remove(nil) }.not_to raise_error
    end

    it 'does not raise an error for invalid item' do
      expect { purchase.remove('invalid') }.not_to raise_error
    end
  end
end
describe '.organization_summary_by_dates', :phoenix do
  let(:organization) { create(:organization) }
  let(:vendor) { create(:vendor, organization: organization) }
  let(:date_range) { Date.today.beginning_of_month..Date.today.end_of_month }
  let!(:purchase) { create(:purchase, organization: organization, vendor: vendor, amount_spent_in_cents: 1000, amount_spent_on_period_supplies_cents: 300, amount_spent_on_diapers_cents: 200, amount_spent_on_adult_incontinence_cents: 100, amount_spent_on_other_cents: 400, created_at: Date.today) }
  let!(:purchase_with_items) { create(:purchase, :with_items, organization: organization, vendor: vendor, created_at: Date.today) }

  it 'returns zero amounts when there are no purchases in the date range' do
    summary = Purchase.organization_summary_by_dates(organization, Date.today.next_month..Date.today.next_month.end_of_month)
    expect(summary.amount_spent).to eq(0)
  end

  it 'returns zero period supplies when there are no purchases in the date range' do
    summary = Purchase.organization_summary_by_dates(organization, Date.today.next_month..Date.today.next_month.end_of_month)
    expect(summary.period_supplies).to eq(0)
  end

  it 'returns zero diapers when there are no purchases in the date range' do
    summary = Purchase.organization_summary_by_dates(organization, Date.today.next_month..Date.today.next_month.end_of_month)
    expect(summary.diapers).to eq(0)
  end

  it 'returns zero adult incontinence when there are no purchases in the date range' do
    summary = Purchase.organization_summary_by_dates(organization, Date.today.next_month..Date.today.next_month.end_of_month)
    expect(summary.adult_incontinence).to eq(0)
  end

  it 'returns zero other categories when there are no purchases in the date range' do
    summary = Purchase.organization_summary_by_dates(organization, Date.today.next_month..Date.today.next_month.end_of_month)
    expect(summary.other).to eq(0)
  end

  it 'returns zero total items when there are no purchases in the date range' do
    summary = Purchase.organization_summary_by_dates(organization, Date.today.next_month..Date.today.next_month.end_of_month)
    expect(summary.total_items).to eq(0)
  end

  it 'calculates total amount spent when there are purchases in the date range' do
    summary = Purchase.organization_summary_by_dates(organization, date_range)
    expect(summary.amount_spent).to eq(1000)
  end

  describe 'when purchases include different categories' do
    it 'calculates amount spent on period supplies' do
      summary = Purchase.organization_summary_by_dates(organization, date_range)
      expect(summary.period_supplies).to eq(300)
    end

    it 'calculates amount spent on diapers' do
      summary = Purchase.organization_summary_by_dates(organization, date_range)
      expect(summary.diapers).to eq(200)
    end

    it 'calculates amount spent on adult incontinence' do
      summary = Purchase.organization_summary_by_dates(organization, date_range)
      expect(summary.adult_incontinence).to eq(100)
    end

    it 'calculates amount spent on other categories' do
      summary = Purchase.organization_summary_by_dates(organization, date_range)
      expect(summary.other).to eq(400)
    end
  end

  it 'calculates total items from line items quantities' do
    summary = Purchase.organization_summary_by_dates(organization, date_range)
    expect(summary.total_items).to eq(purchase_with_items.line_items.sum(:quantity))
  end

  it 'includes recent purchases with vendors' do
    summary = Purchase.organization_summary_by_dates(organization, date_range)
    expect(summary.recent_purchases).to include(purchase)
  end
end
describe '#combine_duplicates', :phoenix do
  let(:purchase) { build(:purchase) }

  context 'when there are no line items' do
    it 'does not change the line items size' do
      expect { purchase.combine_duplicates }.not_to change { purchase.line_items.size }
    end
  end

  context 'when there are valid line items with non-zero quantities' do
    let(:purchase) { build(:purchase, :with_items, item_quantity: 5) }

    it 'calls combine! on line items' do
      expect(purchase.line_items).to receive(:combine!)
      purchase.combine_duplicates
    end
  end

  context 'when there are line items with zero quantities' do
    let(:purchase) { build(:purchase, :with_items, item_quantity: 0) }

    it 'does not change the line items size' do
      expect { purchase.combine_duplicates }.not_to change { purchase.line_items.size }
    end
  end

  context 'when there are invalid line items' do
    let(:purchase) { build(:purchase) }

    before do
      allow_any_instance_of(LineItem).to receive(:valid?).and_return(false)
    end

    it 'does not change the line items size' do
      expect { purchase.combine_duplicates }.not_to change { purchase.line_items.size }
    end
  end

  context 'when there are line items with the same item_id' do
    let(:item) { create(:item) }
    let(:purchase) { build(:purchase, :with_items, item: item, item_quantity: 5) }

    it 'increases the total quantity of line items by 5' do
      expect { purchase.combine_duplicates }.to change { purchase.line_items.map(&:quantity).sum }.by(5)
    end
  end
end
describe '#strip_symbols_from_money', :phoenix do
  let(:purchase_with_symbols) { build(:purchase, amount_spent: '$1,000', amount_spent_on_diapers: '$200', amount_spent_on_adult_incontinence: '$300', amount_spent_on_period_supplies: '$100', amount_spent_on_other: '$400') }
  let(:purchase_without_symbols) { build(:purchase, amount_spent: '1000', amount_spent_on_diapers: '200', amount_spent_on_adult_incontinence: '300', amount_spent_on_period_supplies: '100', amount_spent_on_other: '400') }
  let(:purchase_non_string) { build(:purchase, amount_spent: 1000, amount_spent_on_diapers: 200, amount_spent_on_adult_incontinence: 300, amount_spent_on_period_supplies: 100, amount_spent_on_other: 400) }
  let(:purchase_only_symbols) { build(:purchase, amount_spent: '$', amount_spent_on_diapers: '$', amount_spent_on_adult_incontinence: '$', amount_spent_on_period_supplies: '$', amount_spent_on_other: '$') }
  let(:purchase_empty_string) { build(:purchase, amount_spent: '', amount_spent_on_diapers: '', amount_spent_on_adult_incontinence: '', amount_spent_on_period_supplies: '', amount_spent_on_other: '') }

  it 'strips symbols from amount_spent' do
    purchase_with_symbols.strip_symbols_from_money
    expect(purchase_with_symbols.amount_spent).to eq(1000)
  end

  it 'strips symbols from amount_spent_on_diapers' do
    purchase_with_symbols.strip_symbols_from_money
    expect(purchase_with_symbols.amount_spent_on_diapers).to eq(200)
  end

  it 'strips symbols from amount_spent_on_adult_incontinence' do
    purchase_with_symbols.strip_symbols_from_money
    expect(purchase_with_symbols.amount_spent_on_adult_incontinence).to eq(300)
  end

  it 'strips symbols from amount_spent_on_period_supplies' do
    purchase_with_symbols.strip_symbols_from_money
    expect(purchase_with_symbols.amount_spent_on_period_supplies).to eq(100)
  end

  it 'strips symbols from amount_spent_on_other' do
    purchase_with_symbols.strip_symbols_from_money
    expect(purchase_with_symbols.amount_spent_on_other).to eq(400)
  end

  it 'handles string without symbols for amount_spent' do
    purchase_without_symbols.strip_symbols_from_money
    expect(purchase_without_symbols.amount_spent).to eq(1000)
  end

  it 'handles string without symbols for amount_spent_on_diapers' do
    purchase_without_symbols.strip_symbols_from_money
    expect(purchase_without_symbols.amount_spent_on_diapers).to eq(200)
  end

  it 'handles string without symbols for amount_spent_on_adult_incontinence' do
    purchase_without_symbols.strip_symbols_from_money
    expect(purchase_without_symbols.amount_spent_on_adult_incontinence).to eq(300)
  end

  it 'handles string without symbols for amount_spent_on_period_supplies' do
    purchase_without_symbols.strip_symbols_from_money
    expect(purchase_without_symbols.amount_spent_on_period_supplies).to eq(100)
  end

  it 'handles string without symbols for amount_spent_on_other' do
    purchase_without_symbols.strip_symbols_from_money
    expect(purchase_without_symbols.amount_spent_on_other).to eq(400)
  end

  it 'does nothing if amount_spent is not a string' do
    purchase_non_string.strip_symbols_from_money
    expect(purchase_non_string.amount_spent).to eq(1000)
  end

  it 'does nothing if amount_spent_on_diapers is not a string' do
    purchase_non_string.strip_symbols_from_money
    expect(purchase_non_string.amount_spent_on_diapers).to eq(200)
  end

  it 'does nothing if amount_spent_on_adult_incontinence is not a string' do
    purchase_non_string.strip_symbols_from_money
    expect(purchase_non_string.amount_spent_on_adult_incontinence).to eq(300)
  end

  it 'does nothing if amount_spent_on_period_supplies is not a string' do
    purchase_non_string.strip_symbols_from_money
    expect(purchase_non_string.amount_spent_on_period_supplies).to eq(100)
  end

  it 'does nothing if amount_spent_on_other is not a string' do
    purchase_non_string.strip_symbols_from_money
    expect(purchase_non_string.amount_spent_on_other).to eq(400)
  end

  it 'handles string with only symbols for amount_spent' do
    purchase_only_symbols.strip_symbols_from_money
    expect(purchase_only_symbols.amount_spent).to eq(0)
  end

  it 'handles string with only symbols for amount_spent_on_diapers' do
    purchase_only_symbols.strip_symbols_from_money
    expect(purchase_only_symbols.amount_spent_on_diapers).to eq(0)
  end

  it 'handles string with only symbols for amount_spent_on_adult_incontinence' do
    purchase_only_symbols.strip_symbols_from_money
    expect(purchase_only_symbols.amount_spent_on_adult_incontinence).to eq(0)
  end

  it 'handles string with only symbols for amount_spent_on_period_supplies' do
    purchase_only_symbols.strip_symbols_from_money
    expect(purchase_only_symbols.amount_spent_on_period_supplies).to eq(0)
  end

  it 'handles string with only symbols for amount_spent_on_other' do
    purchase_only_symbols.strip_symbols_from_money
    expect(purchase_only_symbols.amount_spent_on_other).to eq(0)
  end

  it 'handles empty string for amount_spent' do
    purchase_empty_string.strip_symbols_from_money
    expect(purchase_empty_string.amount_spent).to eq(0)
  end

  it 'handles empty string for amount_spent_on_diapers' do
    purchase_empty_string.strip_symbols_from_money
    expect(purchase_empty_string.amount_spent_on_diapers).to eq(0)
  end

  it 'handles empty string for amount_spent_on_adult_incontinence' do
    purchase_empty_string.strip_symbols_from_money
    expect(purchase_empty_string.amount_spent_on_adult_incontinence).to eq(0)
  end

  it 'handles empty string for amount_spent_on_period_supplies' do
    purchase_empty_string.strip_symbols_from_money
    expect(purchase_empty_string.amount_spent_on_period_supplies).to eq(0)
  end

  it 'handles empty string for amount_spent_on_other' do
    purchase_empty_string.strip_symbols_from_money
    expect(purchase_empty_string.amount_spent_on_other).to eq(0)
  end
end
describe '#total_equal_to_all_categories', :phoenix do
  let(:purchase) { build(:purchase, amount_spent_in_cents: amount_spent_in_cents, amount_spent_on_diapers_cents: amount_spent_on_diapers_cents, amount_spent_on_adult_incontinence_cents: amount_spent_on_adult_incontinence_cents, amount_spent_on_period_supplies_cents: amount_spent_on_period_supplies_cents, amount_spent_on_other_cents: amount_spent_on_other_cents) }

  context 'when amount_spent is nil or zero' do
    let(:amount_spent_in_cents) { 0 }
    let(:amount_spent_on_diapers_cents) { 0 }
    let(:amount_spent_on_adult_incontinence_cents) { 0 }
    let(:amount_spent_on_period_supplies_cents) { 0 }
    let(:amount_spent_on_other_cents) { 0 }

    it 'returns without adding an error' do
      purchase.total_equal_to_all_categories
      expect(purchase.errors[:amount_spent]).to be_empty
    end
  end

  context 'when all category amounts are nil or zero' do
    let(:amount_spent_in_cents) { 1000 }
    let(:amount_spent_on_diapers_cents) { 0 }
    let(:amount_spent_on_adult_incontinence_cents) { 0 }
    let(:amount_spent_on_period_supplies_cents) { 0 }
    let(:amount_spent_on_other_cents) { 0 }

    it 'returns without adding an error' do
      purchase.total_equal_to_all_categories
      expect(purchase.errors[:amount_spent]).to be_empty
    end
  end

  context 'when category total equals amount_spent' do
    let(:amount_spent_in_cents) { 1000 }
    let(:amount_spent_on_diapers_cents) { 250 }
    let(:amount_spent_on_adult_incontinence_cents) { 250 }
    let(:amount_spent_on_period_supplies_cents) { 250 }
    let(:amount_spent_on_other_cents) { 250 }

    it 'does not add an error' do
      purchase.total_equal_to_all_categories
      expect(purchase.errors[:amount_spent]).to be_empty
    end
  end

  context 'when category total does not equal amount_spent' do
    let(:amount_spent_in_cents) { 1000 }
    let(:amount_spent_on_diapers_cents) { 200 }
    let(:amount_spent_on_adult_incontinence_cents) { 200 }
    let(:amount_spent_on_period_supplies_cents) { 200 }
    let(:amount_spent_on_other_cents) { 200 }

    it 'adds an error' do
      purchase.total_equal_to_all_categories
      expect(purchase.errors[:amount_spent]).to include('does not equal all categories - categories add to $8.00 but given total is $10.00')
    end
  end
end
end
