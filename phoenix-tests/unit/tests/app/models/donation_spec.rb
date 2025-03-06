
require "rails_helper"

RSpec.describe Donation do
describe '#from_product_drive?', :phoenix do
  let(:product_drive_donation) { build(:product_drive_donation) }
  let(:misc_donation) { build(:donation) }

  it 'returns true when the donation source is product drive' do
    donation = product_drive_donation
    expect(donation.from_product_drive?).to be true
  end

  it 'returns false when the donation source is not product drive' do
    donation = misc_donation
    expect(donation.from_product_drive?).to be false
  end
end
describe '#from_manufacturer?', :phoenix do
  let(:manufacturer_donation) { build(:manufacturer_donation) }
  let(:non_manufacturer_donation) { build(:donation) }

  it 'returns true when the donation source is manufacturer' do
    donation = manufacturer_donation
    expect(donation.from_manufacturer?).to be true
  end

  it 'returns false when the donation source is not manufacturer' do
    donation = non_manufacturer_donation
    expect(donation.from_manufacturer?).to be false
  end
end
describe '#from_donation_site?', :phoenix do
  let(:donation_site_donation) { build(:donation, source: Donation::SOURCES[:donation_site]) }
  let(:other_source_donation) { build(:donation, source: Donation::SOURCES[:misc]) }

  it 'returns true when the source is donation_site' do
    expect(donation_site_donation.from_donation_site?).to eq(true)
  end

  it 'returns false when the source is not donation_site' do
    expect(other_source_donation.from_donation_site?).to eq(false)
  end
end
describe "#source_view", :phoenix do
  let(:organization) { create(:organization) }
  let(:product_drive) { build(:product_drive, organization: organization) }
  let(:product_drive_participant) { build(:product_drive_participant, organization: organization) }

  context "when not from product drive" do
    let(:donation) { build(:donation, source: 'some_source', product_drive: nil, product_drive_participant: nil) }

    it "returns the source when not from product drive" do
      expect(donation.source_view).to eq('some_source')
    end
  end

  context "when from product drive" do
    let(:donation) { build(:product_drive_donation, product_drive: product_drive, product_drive_participant: product_drive_participant) }

    context "when product_drive_participant's donation_source_view is present" do
      before do
        allow(product_drive_participant).to receive(:donation_source_view).and_return('participant_view')
      end

      it "returns product_drive_participant's donation_source_view" do
        expect(donation.source_view).to eq('participant_view')
      end
    end

    context "when product_drive_participant's donation_source_view is nil" do
      before do
        allow(product_drive_participant).to receive(:donation_source_view).and_return(nil)
        allow(product_drive).to receive(:donation_source_view).and_return('drive_view')
      end

      it "returns product_drive's donation_source_view" do
        expect(donation.source_view).to eq('drive_view')
      end
    end
  end
end
describe '#daily_quantities_by_source', :phoenix do
  let(:organization) { create(:organization) }
  let(:storage_location) { create(:storage_location, organization: organization) }
  let(:item) { create(:item) }

  let(:donation_with_items) do
    create(:donation, :with_items, organization: organization, storage_location: storage_location, item: item, item_quantity: 50)
  end

  let(:donation_without_items) do
    create(:donation, organization: organization, storage_location: storage_location)
  end

  let(:start_date) { Date.today.beginning_of_month }
  let(:stop_date) { Date.today.end_of_month }

  it 'returns correct quantities for a given date range and source' do
    donation_with_items
    result = Donation.daily_quantities_by_source(start_date, stop_date)
    expect(result).to eq({ donation_with_items.source => { Date.today => 50 } })
  end

  describe 'when there are no donations in the given date range' do
    it 'returns an empty result' do
      result = Donation.daily_quantities_by_source(start_date, stop_date)
      expect(result).to be_empty
    end
  end

  describe 'when there are multiple sources' do
    let(:another_donation_with_items) do
      create(:manufacturer_donation, :with_items, organization: organization, storage_location: storage_location, item: item, item_quantity: 30)
    end

    it 'groups quantities by each source' do
      donation_with_items
      another_donation_with_items
      result = Donation.daily_quantities_by_source(start_date, stop_date)
      expect(result).to eq({
        donation_with_items.source => { Date.today => 50 },
        another_donation_with_items.source => { Date.today => 30 }
      })
    end
  end

  describe 'when donations have no line items' do
    it 'returns zero quantities' do
      donation_without_items
      result = Donation.daily_quantities_by_source(start_date, stop_date)
      expect(result).to eq({ donation_without_items.source => { Date.today => 0 } })
    end
  end

  describe 'when start date is after stop date' do
    let(:start_date) { Date.today.end_of_month }
    let(:stop_date) { Date.today.beginning_of_month }

    it 'handles invalid date range gracefully' do
      result = Donation.daily_quantities_by_source(start_date, stop_date)
      expect(result).to be_empty
    end
  end

  describe 'when there are donations on the boundary dates' do
    let(:boundary_donation_start) do
      create(:donation, :with_items, organization: organization, storage_location: storage_location, item: item, item_quantity: 20, issued_at: start_date)
    end

    let(:boundary_donation_stop) do
      create(:donation, :with_items, organization: organization, storage_location: storage_location, item: item, item_quantity: 20, issued_at: stop_date)
    end

    it 'includes donations on the start date' do
      boundary_donation_start
      result = Donation.daily_quantities_by_source(start_date, stop_date)
      expect(result).to include(boundary_donation_start.source => { start_date => 20 })
    end

    it 'includes donations on the stop date' do
      boundary_donation_stop
      result = Donation.daily_quantities_by_source(start_date, stop_date)
      expect(result).to include(boundary_donation_stop.source => { stop_date => 20 })
    end
  end
end
describe '#details', :phoenix do
  let(:product_drive) { build(:product_drive, name: 'Test Drive') }
  let(:manufacturer) { build(:manufacturer, name: 'Test Manufacturer') }
  let(:donation_site) { build(:donation_site, name: 'Test Donation Site') }
  let(:comment) { 'This is a test comment that is quite long and needs truncation.' }

  context 'when source is product_drive' do
    let(:donation) { build(:product_drive_donation, product_drive: product_drive) }

    it 'returns the product drive name' do
      expect(donation.details).to eq('Test Drive')
    end
  end

  context 'when source is manufacturer' do
    let(:donation) { build(:manufacturer_donation, manufacturer: manufacturer) }

    it 'returns the manufacturer name' do
      expect(donation.details).to eq('Test Manufacturer')
    end
  end

  context 'when source is donation_site' do
    let(:donation) { build(:donation_site_donation, donation_site: donation_site) }

    it 'returns the donation site name' do
      expect(donation.details).to eq('Test Donation Site')
    end
  end

  context 'when source is misc' do
    let(:donation) { build(:donation, source: Donation::SOURCES[:misc], comment: comment) }

    it 'returns the truncated comment' do
      expect(donation.details).to eq('This is a test comment that is...')
    end

    context 'with nil comment' do
      let(:donation) { build(:donation, source: Donation::SOURCES[:misc], comment: nil) }

      it 'handles nil comment gracefully' do
        expect(donation.details).to be_nil
      end
    end
  end
end
describe '#remove', :phoenix do
  let(:donation) { create(:donation, :with_items) }
  let(:line_item) { donation.line_items.first }
  let(:non_existent_id) { line_item.id + 1 }
  let(:non_convertible_item) { 'non-integer' }

  it 'removes the line item when item is an ID and line item is found' do
    expect { donation.remove(line_item.id) }.to change { donation.line_items.count }.by(-1)
  end

  it 'does nothing when item is an ID and line item is not found' do
    expect { donation.remove(non_existent_id) }.not_to change { donation.line_items.count }
  end

  it 'removes the line item when item is an object and line item is found' do
    expect { donation.remove(line_item) }.to change { donation.line_items.count }.by(-1)
  end

  it 'does nothing when item is an object and line item is not found' do
    non_existent_item = build(:line_item, id: non_existent_id)
    expect { donation.remove(non_existent_item) }.not_to change { donation.line_items.count }
  end

  it 'does nothing when item is not convertible to an integer' do
    expect { donation.remove(non_convertible_item) }.not_to change { donation.line_items.count }
  end
end
describe "#money_raised_in_dollars", :phoenix do
  let(:positive_donation) { build(:donation, money_raised: 10000) }
  let(:zero_donation) { build(:donation, money_raised: 0) }
  let(:negative_donation) { build(:donation, money_raised: -5000) }
  let(:non_integer_donation) { build(:donation, money_raised: 1234.56) }

  it "converts positive money_raised to dollars" do
    expect(positive_donation.money_raised_in_dollars).to eq(100.0)
  end

  it "converts zero money_raised to dollars" do
    expect(zero_donation.money_raised_in_dollars).to eq(0.0)
  end

  it "converts negative money_raised to dollars" do
    expect(negative_donation.money_raised_in_dollars).to eq(-50.0)
  end

  it "handles non-integer money_raised values" do
    expect(non_integer_donation.money_raised_in_dollars).to eq(12.3456)
  end
end
describe "#donation_site_view", :phoenix do
  let(:donation_site) { build(:donation_site) }
  let(:donation_with_site) { build(:donation, donation_site: donation_site) }
  let(:donation_without_site) { build(:donation, donation_site: nil) }

  it "returns 'N/A' when donation_site is nil" do
    donation = donation_without_site
    expect(donation.donation_site_view).to eq("N/A")
  end

  it "returns the name of the donation_site when it is not nil" do
    donation = donation_with_site
    expect(donation.donation_site_view).to eq(donation_site.name)
  end
end
describe "#storage_view", :phoenix do
  let(:storage_location) { build(:storage_location, name: "Main Warehouse") }
  let(:donation_with_location) { build(:donation, storage_location: storage_location) }
  let(:donation_without_location) { build(:donation, storage_location: nil) }

  it "returns 'N/A' when storage_location is nil" do
    expect(donation_without_location.storage_view).to eq("N/A")
  end

  it "returns the name of the storage_location when it is not nil" do
    expect(donation_with_location.storage_view).to eq("Main Warehouse")
  end
end
describe '#in_kind_value_money', :phoenix do
  let(:donation) { build(:donation, value_per_itemizable: value_per_itemizable) }

  context 'when value_per_itemizable is a valid numeric value' do
    let(:value_per_itemizable) { 1000 }

    it 'returns a Money object with the correct amount' do
      expect(donation.in_kind_value_money).to eq(Money.new(1000))
    end
  end

  context 'when value_per_itemizable is nil' do
    let(:value_per_itemizable) { nil }

    it 'raises an ArgumentError' do
      expect { donation.in_kind_value_money }.to raise_error(ArgumentError)
    end
  end

  context 'when value_per_itemizable is 0' do
    let(:value_per_itemizable) { 0 }

    it 'returns a Money object with zero amount' do
      expect(donation.in_kind_value_money).to eq(Money.new(0))
    end
  end

  context 'when value_per_itemizable is negative' do
    let(:value_per_itemizable) { -1000 }

    it 'returns a Money object with the negative amount' do
      expect(donation.in_kind_value_money).to eq(Money.new(-1000))
    end
  end

  context 'when value_per_itemizable is non-numeric' do
    let(:value_per_itemizable) { 'non-numeric' }

    it 'raises an ArgumentError' do
      expect { donation.in_kind_value_money }.to raise_error(ArgumentError)
    end
  end

  it 'raises a StandardError for invalid Money initialization' do
    allow(Money).to receive(:new).and_raise(StandardError)
    expect { donation.in_kind_value_money }.to raise_error(StandardError)
  end
end
describe '#combine_duplicates', :phoenix do
  let(:donation) { build(:donation) }
  let(:item) { create(:item) }

  context 'when there are no line items' do
    it 'does not change the line items count' do
      expect { donation.combine_duplicates }.not_to change { donation.line_items.count }
    end
  end

  context 'when there are line items with zero quantity' do
    let!(:line_item_zero_quantity) { build(:line_item, quantity: 0, item: item, itemizable: donation) }

    it 'does not change the line items count' do
      expect { donation.combine_duplicates }.not_to change { donation.line_items.count }
    end
  end

  context 'when there are line items with the same item_id' do
    let!(:line_item1) { build(:line_item, quantity: 1, item: item, itemizable: donation) }
    let!(:line_item2) { build(:line_item, quantity: 2, item: item, itemizable: donation) }

    it 'reduces the line items count to 1' do
      donation.combine_duplicates
      expect(donation.line_items.count).to eq(1)
    end

    it 'sets the combined line item quantity correctly' do
      donation.combine_duplicates
      expect(donation.line_items.first.quantity).to eq(3)
    end
  end

  context 'when there are line items with different item_ids' do
    let(:different_item) { create(:item) }
    let!(:line_item1) { build(:line_item, quantity: 1, item: item, itemizable: donation) }
    let!(:line_item2) { build(:line_item, quantity: 2, item: different_item, itemizable: donation) }

    it 'does not change the line items count' do
      expect { donation.combine_duplicates }.not_to change { donation.line_items.count }
    end
  end

  context 'when there are invalid line items' do
    let!(:invalid_line_item) { build(:line_item, quantity: -1, item: item, itemizable: donation) }

    it 'does not change the line items count' do
      expect { donation.combine_duplicates }.not_to change { donation.line_items.count }
    end
  end
end
end
