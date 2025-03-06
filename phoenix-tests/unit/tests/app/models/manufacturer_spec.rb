
require "rails_helper"

RSpec.describe Manufacturer do
describe '#volume', :phoenix do
  let(:manufacturer) { create(:manufacturer) }

  context 'when there are no donations' do
    it 'returns 0' do
      expect(manufacturer.volume).to eq(0)
    end
  end

  context 'when there are donations but no line items' do
    let!(:donation_without_items) { create(:manufacturer_donation, manufacturer: manufacturer) }

    it 'returns 0' do
      expect(manufacturer.volume).to eq(0)
    end
  end

  context 'when there are donations with line items' do
    let!(:donation_with_items) { create(:manufacturer_donation, :with_items, manufacturer: manufacturer) }

    it 'returns the sum of quantities' do
      expect(manufacturer.volume).to eq(donation_with_items.line_items.sum(:quantity))
    end
  end

  context 'when the sum of quantities is zero' do
    let!(:donation_with_items) { create(:manufacturer_donation, :with_items, manufacturer: manufacturer) }

    before do
      allow_any_instance_of(LineItem).to receive(:quantity).and_return(0)
    end

    it 'returns 0' do
      expect(manufacturer.volume).to eq(0)
    end
  end

  context 'when the sum of quantities is greater than zero' do
    let!(:donation_with_items) { create(:manufacturer_donation, :with_items, manufacturer: manufacturer) }

    it 'returns the correct sum' do
      expect(manufacturer.volume).to eq(donation_with_items.line_items.sum(:quantity))
    end
  end
end
describe '#by_donation_count', :phoenix do
  let(:organization) { create(:organization) }
  let(:manufacturer_with_donations) do
    create(:manufacturer, organization: organization).tap do |manufacturer|
      create(:manufacturer_donation, :with_items, manufacturer: manufacturer, organization: organization, issued_at: 1.day.ago)
    end
  end
  let(:manufacturer_without_donations) { create(:manufacturer, organization: organization) }

  it 'includes manufacturers with donations within the default count limit' do
    result = Manufacturer.by_donation_count
    expect(result).to include(manufacturer_with_donations)
  end

  it 'excludes manufacturers without donations within the default count limit' do
    result = Manufacturer.by_donation_count
    expect(result).not_to include(manufacturer_without_donations)
  end

  context 'when a date_range is specified' do
    let(:date_range) { 2.days.ago..Time.current }

    it 'includes manufacturers with donations within the specified date range' do
      result = Manufacturer.by_donation_count(10, date_range)
      expect(result).to include(manufacturer_with_donations)
    end

    it 'returns no manufacturers if there are no donations in the specified date range' do
      result = Manufacturer.by_donation_count(10, 3.days.ago..2.days.ago)
      expect(result).to be_empty
    end
  end

  it 'excludes manufacturers with zero donation quantities' do
    result = Manufacturer.by_donation_count
    expect(result).not_to include(manufacturer_without_donations)
  end

  it 'limits the number of manufacturers returned to the specified count' do
    create_list(:manufacturer_donation, 15, :with_items, manufacturer: manufacturer_with_donations, organization: organization, issued_at: 1.day.ago)
    result = Manufacturer.by_donation_count(5)
    expect(result.size).to eq(5)
  end

  it 'orders manufacturers by donation count in descending order' do
    another_manufacturer = create(:manufacturer, organization: organization)
    create(:manufacturer_donation, :with_items, manufacturer: another_manufacturer, organization: organization, issued_at: 1.day.ago, quantity: 20)
    result = Manufacturer.by_donation_count
    expect(result.first).to eq(another_manufacturer)
  end
end
describe "#exists_in_org?", :phoenix do
  let(:organization) { create(:organization) }
  let(:manufacturer) { build(:manufacturer, organization: organization, name: manufacturer_name) }
  let(:manufacturer_name) { "Test Manufacturer" }

  it "returns true when the manufacturer exists in the organization" do
    create(:manufacturer, organization: organization, name: manufacturer_name)
    expect(manufacturer.exists_in_org?).to be true
  end

  it "returns false when the manufacturer does not exist in the organization" do
    expect(manufacturer.exists_in_org?).to be false
  end

  describe "when the organization has no manufacturers" do
    let(:organization) { create(:organization) }

    it "returns false" do
      expect(manufacturer.exists_in_org?).to be false
    end
  end
end
end
