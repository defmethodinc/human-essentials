require "rails_helper"

RSpec.describe Purchase do
  describe '#storage_view', :phoenix do
    let(:purchase_with_nil_storage) { Purchase.create(storage_location: nil) }
    let(:storage_location) { StorageLocation.create(name: 'Warehouse A') }
    let(:purchase_with_storage) { Purchase.create(storage_location: storage_location) }

    context 'when storage_location is nil' do
      it "returns 'N/A'" do
        expect(purchase_with_nil_storage.storage_view).to eq('N/A')
      end
    end

    context 'when storage_location is not nil' do
      it 'returns the name of the storage_location' do
        expect(purchase_with_storage.storage_view).to eq('Warehouse A')
      end
    end
  end

  describe "#purchased_from_view", :phoenix do
    let(:purchase_with_nil_vendor) { Purchase.create(purchased_from: "Online Store", vendor: nil) }
    let(:vendor) { Vendor.create(business_name: "Local Shop") }
    let(:purchase_with_vendor) { Purchase.create(purchased_from: "Online Store", vendor: vendor) }

    context "when vendor is nil" do
      it "returns purchased_from" do
        expect(purchase_with_nil_vendor.purchased_from_view).to eq("Online Store")
      end
    end

    context "when vendor is not nil" do
      it "returns vendor's business_name" do
        expect(purchase_with_vendor.purchased_from_view).to eq("Local Shop")
      end
    end
  end

  describe "#amount_spent_in_dollars", :phoenix do
    let(:purchase) { Purchase.new(amount_spent: amount_spent) }

    context "when amount_spent is a valid Money object" do
      let(:amount_spent) { Money.new(1000, "USD") } # $10.00

      it "converts a valid Money object to dollars as a float" do
        expect(purchase.amount_spent_in_dollars).to eq(10.0)
      end
    end

    context "when amount_spent is nil" do
      let(:amount_spent) { nil }

      it "handles the nil case gracefully" do
        expect(purchase.amount_spent_in_dollars).to eq(0.0)
      end
    end

    context "when amount_spent is zero" do
      let(:amount_spent) { Money.new(0, "USD") }

      it "returns 0.0" do
        expect(purchase.amount_spent_in_dollars).to eq(0.0)
      end
    end

    context "when amount_spent is negative" do
      let(:amount_spent) { Money.new(-500, "USD") } # -$5.00

      it "returns the negative dollar amount as a float" do
        expect(purchase.amount_spent_in_dollars).to eq(-5.0)
      end
    end

    context "when amount_spent is a very large value" do
      let(:amount_spent) { Money.new(1000000000, "USD") } # $10,000,000.00

      it "returns the large dollar amount as a float" do
        expect(purchase.amount_spent_in_dollars).to eq(10000000.0)
      end
    end
  end

  describe "#remove", :phoenix do
    let(:purchase) { Purchase.create }
    let(:line_item) { LineItem.create(purchase: purchase, item_id: existing_item_id) }
    let(:existing_item_id) { 1 }
    let(:non_existing_item_id) { 999 }
    let(:invalid_item_id) { "invalid" }

    context "when item is an ID" do
      it "removes the line item if it exists" do
        line_item # Ensure the line item is created
        expect { purchase.remove(existing_item_id) }.to change { LineItem.count }.by(-1)
      end

      it "does not remove any line item if it does not exist" do
        expect { purchase.remove(non_existing_item_id) }.not_to change { LineItem.count }
      end
    end

    context "when item is an object" do
      it "removes the line item if the ID exists" do
        line_item # Ensure the line item is created
        expect { purchase.remove(line_item) }.to change { LineItem.count }.by(-1)
      end

      it "does not remove any line item if the ID does not exist" do
        non_existing_line_item = LineItem.new(purchase: purchase, item_id: non_existing_item_id)
        expect { purchase.remove(non_existing_line_item) }.not_to change { LineItem.count }
      end

      it "does not remove any line item if the ID is invalid" do
        invalid_line_item = LineItem.new(purchase: purchase, item_id: invalid_item_id)
        expect { purchase.remove(invalid_line_item) }.not_to change { LineItem.count }
      end
    end

    context "when item is a non-numeric string" do
      it "does not remove any line item" do
        expect { purchase.remove("non-numeric") }.not_to change { LineItem.count }
      end
    end
  end

  describe '#organization_summary_by_dates', :phoenix do
    let(:organization) { create(:organization) }
    let(:date_range) { Date.today.beginning_of_month..Date.today.end_of_month }
    let(:purchase) { create(:purchase, organization: organization) }

    describe 'when calculating amount spent' do
      it 'returns the correct total amount spent in cents' do
        expect(Purchase.organization_summary_by_dates(organization, date_range).amount_spent).
          to eq(purchase.amount_spent_in_cents)
      end
    end

    describe 'when fetching recent purchases' do
      it 'includes recent purchases with vendor' do
        expect(Purchase.organization_summary_by_dates(organization, date_range).recent_purchases).
          to include(purchase)
      end
    end

    describe 'when calculating period supplies' do
      it 'returns the correct amount spent on period supplies in cents' do
        expect(Purchase.organization_summary_by_dates(organization, date_range).period_supplies).
          to eq(purchase.amount_spent_on_period_supplies_cents)
      end
    end

    describe 'when calculating diapers' do
      it 'returns the correct amount spent on diapers in cents' do
        expect(Purchase.organization_summary_by_dates(organization, date_range).diapers).
          to eq(purchase.amount_spent_on_diapers_cents)
      end
    end

    describe 'when calculating adult incontinence' do
      it 'returns the correct amount spent on adult incontinence in cents' do
        expect(Purchase.organization_summary_by_dates(organization, date_range).adult_incontinence).
          to eq(purchase.amount_spent_on_adult_incontinence_cents)
      end
    end

    describe 'when calculating other expenses' do
      it 'returns the correct amount spent on other items in cents' do
        expect(Purchase.organization_summary_by_dates(organization, date_range).other).
          to eq(purchase.amount_spent_on_other_cents)
      end
    end

    describe 'when calculating total items' do
      it 'returns the correct total quantity of items' do
        expect(Purchase.organization_summary_by_dates(organization, date_range).total_items).
          to eq(purchase.line_items.sum(:quantity))
      end
    end
  end

  describe "#combine_duplicates", :phoenix do
    let(:purchase) { Purchase.create }
    let(:line_item1) { LineItem.create(purchase: purchase, item_id: 1, quantity: 1) }
    let(:line_item2) { LineItem.create(purchase: purchase, item_id: 2, quantity: 1) }
    let(:duplicate_line_item) { LineItem.create(purchase: purchase, item_id: 1, quantity: 1) }
    let(:zero_quantity_line_item) { LineItem.create(purchase: purchase, item_id: 3, quantity: 0) }

    it "does nothing when there are no line items" do
      expect { purchase.combine_duplicates }.not_to change { LineItem.count }
    end

    it "does nothing when all line items have unique item_ids" do
      line_item1
      line_item2
      expect { purchase.combine_duplicates }.not_to change { LineItem.count }
    end

    it "combines line items with duplicate item_ids" do
      line_item1
      duplicate_line_item
      expect { purchase.combine_duplicates }.to change { line_item1.reload.quantity }.from(1).to(2)
    end

    it "ignores invalid line items with zero quantity" do
      zero_quantity_line_item
      expect { purchase.combine_duplicates }.not_to change { LineItem.count }
    end

    it "logs a message when combine! is called" do
      line_item1
      duplicate_line_item
      expect(Rails.logger).to receive(:info).with("[!] Purchase.combine_duplicates: Combining!")
      purchase.combine_duplicates
    end
  end

  describe "#strip_symbols_from_money", :phoenix do
    let(:purchase_with_dollar_and_commas) { Purchase.new(amount_spent: "$1,000", amount_spent_on_diapers: "$200", amount_spent_on_adult_incontinence: "$300", amount_spent_on_period_supplies: "$150", amount_spent_on_other: "$50") }
    let(:purchase_without_dollar_and_commas) { Purchase.new(amount_spent: "1000", amount_spent_on_diapers: "200", amount_spent_on_adult_incontinence: "300", amount_spent_on_period_supplies: "150", amount_spent_on_other: "50") }
    let(:purchase_with_integers) { Purchase.new(amount_spent: 1000, amount_spent_on_diapers: 200, amount_spent_on_adult_incontinence: 300, amount_spent_on_period_supplies: 150, amount_spent_on_other: 50) }
    let(:purchase_with_empty_strings) { Purchase.new(amount_spent: "", amount_spent_on_diapers: "", amount_spent_on_adult_incontinence: "", amount_spent_on_period_supplies: "", amount_spent_on_other: "") }
    let(:purchase_with_non_numeric_strings) { Purchase.new(amount_spent: "abc", amount_spent_on_diapers: "xyz", amount_spent_on_adult_incontinence: "lmn", amount_spent_on_period_supplies: "opq", amount_spent_on_other: "rst") }
    let(:purchase_with_nil_values) { Purchase.new(amount_spent: nil, amount_spent_on_diapers: nil, amount_spent_on_adult_incontinence: nil, amount_spent_on_period_supplies: nil, amount_spent_on_other: nil) }
    let(:purchase_with_non_string_non_integer) { Purchase.new(amount_spent: [], amount_spent_on_diapers: {}, amount_spent_on_adult_incontinence: :symbol, amount_spent_on_period_supplies: 3.14, amount_spent_on_other: true) }

    it "converts string with dollar signs and commas to integer for amount_spent" do
      purchase_with_dollar_and_commas.strip_symbols_from_money
      expect(purchase_with_dollar_and_commas.amount_spent).to eq(1000)
    end

    it "converts string with dollar signs and commas to integer for amount_spent_on_diapers" do
      purchase_with_dollar_and_commas.strip_symbols_from_money
      expect(purchase_with_dollar_and_commas.amount_spent_on_diapers).to eq(200)
    end

    it "converts string with dollar signs and commas to integer for amount_spent_on_adult_incontinence" do
      purchase_with_dollar_and_commas.strip_symbols_from_money
      expect(purchase_with_dollar_and_commas.amount_spent_on_adult_incontinence).to eq(300)
    end

    it "converts string with dollar signs and commas to integer for amount_spent_on_period_supplies" do
      purchase_with_dollar_and_commas.strip_symbols_from_money
      expect(purchase_with_dollar_and_commas.amount_spent_on_period_supplies).to eq(150)
    end

    it "converts string with dollar signs and commas to integer for amount_spent_on_other" do
      purchase_with_dollar_and_commas.strip_symbols_from_money
      expect(purchase_with_dollar_and_commas.amount_spent_on_other).to eq(50)
    end

    it "converts string without dollar signs and commas to integer for amount_spent" do
      purchase_without_dollar_and_commas.strip_symbols_from_money
      expect(purchase_without_dollar_and_commas.amount_spent).to eq(1000)
    end

    it "converts string without dollar signs and commas to integer for amount_spent_on_diapers" do
      purchase_without_dollar_and_commas.strip_symbols_from_money
      expect(purchase_without_dollar_and_commas.amount_spent_on_diapers).to eq(200)
    end

    it "converts string without dollar signs and commas to integer for amount_spent_on_adult_incontinence" do
      purchase_without_dollar_and_commas.strip_symbols_from_money
      expect(purchase_without_dollar_and_commas.amount_spent_on_adult_incontinence).to eq(300)
    end

    it "converts string without dollar signs and commas to integer for amount_spent_on_period_supplies" do
      purchase_without_dollar_and_commas.strip_symbols_from_money
      expect(purchase_without_dollar_and_commas.amount_spent_on_period_supplies).to eq(150)
    end

    it "converts string without dollar signs and commas to integer for amount_spent_on_other" do
      purchase_without_dollar_and_commas.strip_symbols_from_money
      expect(purchase_without_dollar_and_commas.amount_spent_on_other).to eq(50)
    end

    it "leaves integer values unchanged for amount_spent" do
      purchase_with_integers.strip_symbols_from_money
      expect(purchase_with_integers.amount_spent).to eq(1000)
    end

    it "leaves integer values unchanged for amount_spent_on_diapers" do
      purchase_with_integers.strip_symbols_from_money
      expect(purchase_with_integers.amount_spent_on_diapers).to eq(200)
    end

    it "leaves integer values unchanged for amount_spent_on_adult_incontinence" do
      purchase_with_integers.strip_symbols_from_money
      expect(purchase_with_integers.amount_spent_on_adult_incontinence).to eq(300)
    end

    it "leaves integer values unchanged for amount_spent_on_period_supplies" do
      purchase_with_integers.strip_symbols_from_money
      expect(purchase_with_integers.amount_spent_on_period_supplies).to eq(150)
    end

    it "leaves integer values unchanged for amount_spent_on_other" do
      purchase_with_integers.strip_symbols_from_money
      expect(purchase_with_integers.amount_spent_on_other).to eq(50)
    end

    it "handles empty string values for amount_spent" do
      purchase_with_empty_strings.strip_symbols_from_money
      expect(purchase_with_empty_strings.amount_spent).to eq(0)
    end

    it "handles empty string values for amount_spent_on_diapers" do
      purchase_with_empty_strings.strip_symbols_from_money
      expect(purchase_with_empty_strings.amount_spent_on_diapers).to eq(0)
    end

    it "handles empty string values for amount_spent_on_adult_incontinence" do
      purchase_with_empty_strings.strip_symbols_from_money
      expect(purchase_with_empty_strings.amount_spent_on_adult_incontinence).to eq(0)
    end

    it "handles empty string values for amount_spent_on_period_supplies" do
      purchase_with_empty_strings.strip_symbols_from_money
      expect(purchase_with_empty_strings.amount_spent_on_period_supplies).to eq(0)
    end

    it "handles empty string values for amount_spent_on_other" do
      purchase_with_empty_strings.strip_symbols_from_money
      expect(purchase_with_empty_strings.amount_spent_on_other).to eq(0)
    end

    it "handles strings with non-numeric characters for amount_spent" do
      purchase_with_non_numeric_strings.strip_symbols_from_money
      expect(purchase_with_non_numeric_strings.amount_spent).to eq(0)
    end

    it "handles strings with non-numeric characters for amount_spent_on_diapers" do
      purchase_with_non_numeric_strings.strip_symbols_from_money
      expect(purchase_with_non_numeric_strings.amount_spent_on_diapers).to eq(0)
    end

    it "handles strings with non-numeric characters for amount_spent_on_adult_incontinence" do
      purchase_with_non_numeric_strings.strip_symbols_from_money
      expect(purchase_with_non_numeric_strings.amount_spent_on_adult_incontinence).to eq(0)
    end

    it "handles strings with non-numeric characters for amount_spent_on_period_supplies" do
      purchase_with_non_numeric_strings.strip_symbols_from_money
      expect(purchase_with_non_numeric_strings.amount_spent_on_period_supplies).to eq(0)
    end

    it "handles strings with non-numeric characters for amount_spent_on_other" do
      purchase_with_non_numeric_strings.strip_symbols_from_money
      expect(purchase_with_non_numeric_strings.amount_spent_on_other).to eq(0)
    end

    it "handles nil values for amount_spent" do
      purchase_with_nil_values.strip_symbols_from_money
      expect(purchase_with_nil_values.amount_spent).to be_nil
    end

    it "handles nil values for amount_spent_on_diapers" do
      purchase_with_nil_values.strip_symbols_from_money
      expect(purchase_with_nil_values.amount_spent_on_diapers).to be_nil
    end

    it "handles nil values for amount_spent_on_adult_incontinence" do
      purchase_with_nil_values.strip_symbols_from_money
      expect(purchase_with_nil_values.amount_spent_on_adult_incontinence).to be_nil
    end

    it "handles nil values for amount_spent_on_period_supplies" do
      purchase_with_nil_values.strip_symbols_from_money
      expect(purchase_with_nil_values.amount_spent_on_period_supplies).to be_nil
    end

    it "handles nil values for amount_spent_on_other" do
      purchase_with_nil_values.strip_symbols_from_money
      expect(purchase_with_nil_values.amount_spent_on_other).to be_nil
    end

    it "handles non-string, non-integer types for amount_spent" do
      purchase_with_non_string_non_integer.strip_symbols_from_money
      expect(purchase_with_non_string_non_integer.amount_spent).to eq([])
    end

    it "handles non-string, non-integer types for amount_spent_on_diapers" do
      purchase_with_non_string_non_integer.strip_symbols_from_money
      expect(purchase_with_non_string_non_integer.amount_spent_on_diapers).to eq({})
    end

    it "handles non-string, non-integer types for amount_spent_on_adult_incontinence" do
      purchase_with_non_string_non_integer.strip_symbols_from_money
      expect(purchase_with_non_string_non_integer.amount_spent_on_adult_incontinence).to eq(:symbol)
    end

    it "handles non-string, non-integer types for amount_spent_on_period_supplies" do
      purchase_with_non_string_non_integer.strip_symbols_from_money
      expect(purchase_with_non_string_non_integer.amount_spent_on_period_supplies).to eq(3.14)
    end

    it "handles non-string, non-integer types for amount_spent_on_other" do
      purchase_with_non_string_non_integer.strip_symbols_from_money
      expect(purchase_with_non_string_non_integer.amount_spent_on_other).to eq(true)
    end
  end

  describe '#total_equal_to_all_categories', :phoenix do
    let(:purchase) { create(:purchase, amount_spent: amount_spent, amount_spent_on_diapers: amount_spent_on_diapers, amount_spent_on_adult_incontinence: amount_spent_on_adult_incontinence, amount_spent_on_period_supplies: amount_spent_on_period_supplies, amount_spent_on_other: amount_spent_on_other) }

    context 'when amount_spent is zero' do
      let(:amount_spent) { 0 }
      let(:amount_spent_on_diapers) { 0 }
      let(:amount_spent_on_adult_incontinence) { 0 }
      let(:amount_spent_on_period_supplies) { 0 }
      let(:amount_spent_on_other) { 0 }

      it 'does not add an error' do
        purchase.total_equal_to_all_categories
        expect(purchase.errors[:amount_spent]).to be_empty
      end
    end

    context 'when all category amounts are zero' do
      let(:amount_spent) { 100 }
      let(:amount_spent_on_diapers) { 0 }
      let(:amount_spent_on_adult_incontinence) { 0 }
      let(:amount_spent_on_period_supplies) { 0 }
      let(:amount_spent_on_other) { 0 }

      it 'does not add an error' do
        purchase.total_equal_to_all_categories
        expect(purchase.errors[:amount_spent]).to be_empty
      end
    end

    context 'when category total equals amount_spent' do
      let(:amount_spent) { 100 }
      let(:amount_spent_on_diapers) { 30 }
      let(:amount_spent_on_adult_incontinence) { 20 }
      let(:amount_spent_on_period_supplies) { 25 }
      let(:amount_spent_on_other) { 25 }

      it 'does not add an error' do
        purchase.total_equal_to_all_categories
        expect(purchase.errors[:amount_spent]).to be_empty
      end
    end

    context 'when category total does not equal amount_spent' do
      let(:amount_spent) { 100 }
      let(:amount_spent_on_diapers) { 30 }
      let(:amount_spent_on_adult_incontinence) { 20 }
      let(:amount_spent_on_period_supplies) { 25 }
      let(:amount_spent_on_other) { 20 }

      it 'adds an error to amount_spent' do
        purchase.total_equal_to_all_categories
        expect(purchase.errors[:amount_spent]).to include("does not equal all categories - categories add to $95.00 but given total is $100.00")
      end
    end
  end
end
