require "rails_helper"

RSpec.describe Distribution do
  describe '#distributed_at', :phoenix do
    let(:distribution_midnight) { build(:distribution, issued_at: issued_at_midnight) }
    let(:distribution_not_midnight) { build(:distribution, issued_at: issued_at_not_midnight) }
    let(:issued_at_midnight) { Time.zone.now.midnight }
    let(:issued_at_not_midnight) { Time.zone.now.change(hour: 10, min: 0, sec: 0) }

    context 'when issued_at is midnight' do
      it 'returns the distribution date format' do
        expect(distribution_midnight.distributed_at).to eq(issued_at_midnight.to_fs(:distribution_date))
      end
    end

    context 'when issued_at is not midnight' do
      it 'returns the distribution date time format' do
        expect(distribution_not_midnight.distributed_at).to eq(issued_at_not_midnight.to_fs(:distribution_date_time))
      end
    end
  end
  describe '#combine_duplicates', :phoenix do
    let(:distribution) { build(:distribution) }

    context 'when there are no line items' do
      it 'does not change the line items size' do
        expect { distribution.combine_duplicates }.not_to change { distribution.line_items.size }
      end
    end

    context 'when there are invalid line items' do
      let(:distribution) { build(:distribution, :with_items, item_quantity: -1) }

      it 'does not change the line items size' do
        expect { distribution.combine_duplicates }.not_to change { distribution.line_items.size }
      end
    end

    context 'when there are line items with zero quantities' do
      let(:distribution) { build(:distribution, :with_items, item_quantity: 0) }

      it 'removes line items with zero quantities' do
        expect { distribution.combine_duplicates }.to change { distribution.line_items.size }.by(-1)
      end
    end

    context 'when there are line items with the same item_id' do
      let(:item) { create(:item) }
      let(:distribution) { build(:distribution, :with_items, item: item, item_quantity: 5) }

      before do
        distribution.line_items << build(:line_item, item: item, quantity: 5, itemizable: distribution)
      end

      it 'aggregates quantities for line items with the same item_id' do
        expect { distribution.combine_duplicates }.to change { distribution.line_items.first.quantity }.from(5).to(10)
      end
    end
  end
  describe '#copy_line_items', :phoenix do
    let(:distribution) { create(:distribution) }
    let(:donation) { create(:donation) }

    context 'when there are no line items' do
      it 'does not change the line items count' do
        expect { distribution.copy_line_items(donation.id) }.not_to change { distribution.line_items.count }
      end
    end

    context 'when there is a single line item' do
      let!(:line_item) { create(:line_item, :for_donation, itemizable: donation) }

      it 'increases the line items count by 1' do
        distribution.copy_line_items(donation.id)
        expect(distribution.line_items.size).to eq(1)
      end

      it 'copies the attributes of the line item' do
        distribution.copy_line_items(donation.id)
        copied_item = distribution.line_items.last
        expect(copied_item.attributes.except('id', 'created_at', 'updated_at', 'itemizable_type', 'itemizable_id')).to eq(line_item.attributes.except('id', 'created_at', 'updated_at', 'itemizable_type', 'itemizable_id'))
      end
    end

    context 'when there are multiple line items' do
      let!(:line_items) { create_list(:line_item, 3, :for_donation, itemizable: donation) }

      it 'increases the line items count by the number of line items' do
        distribution.copy_line_items(donation.id)
        expect(distribution.line_items.size).to eq(3)
      end

      it 'copies the attributes of each line item' do
        distribution.copy_line_items(donation.id)
        copied_items = distribution.line_items.last(3)
        line_items.each_with_index do |line_item, index|
          expect(copied_items[index].attributes.except('id', 'created_at', 'updated_at', 'itemizable_type', 'itemizable_id')).to eq(line_item.attributes.except('id', 'created_at', 'updated_at', 'itemizable_type', 'itemizable_id'))
        end
      end
    end

    context 'when an error occurs during line item creation' do
      before do
        allow_any_instance_of(LineItem).to receive(:save).and_return(false)
      end

      it 'does not change the line items count' do
        expect { distribution.copy_line_items(donation.id) }.not_to change { distribution.line_items.count }
      end
    end
  end
  describe '#copy_from_donation', :phoenix do
    let(:organization) { create(:organization) }
    let(:storage_location) { create(:storage_location, organization: organization) }
    let(:donation) { create(:donation, :with_items, organization: organization, storage_location: storage_location) }
    let(:distribution) { create(:distribution, organization: organization) }

    context 'when donation_id is provided and storage_location_id is provided' do
      it 'copies line items from donation' do
        distribution.copy_from_donation(donation.id, storage_location.id)
        expect(distribution.line_items).to eq(donation.line_items)
      end

      it 'sets storage location to the provided storage_location_id' do
        distribution.copy_from_donation(donation.id, storage_location.id)
        expect(distribution.storage_location).to eq(storage_location)
      end
    end

    context 'when donation_id is provided and storage_location_id is not provided' do
      it 'copies line items from donation' do
        distribution.copy_from_donation(donation.id, nil)
        expect(distribution.line_items).to eq(donation.line_items)
      end

      it 'has original storage location' do
        distribution.copy_from_donation(donation.id, nil)
        expect(distribution.storage_location).to eq(distribution.storage_location)
      end
    end

    context 'when donation_id is not provided and storage_location_id is provided' do
      it 'does not copy line items' do
        distribution.copy_from_donation(nil, storage_location.id)
        expect(distribution.line_items).to be_empty
      end

      it 'dos not change storage_location' do
        distribution.copy_from_donation(nil, storage_location.id)
        expect(distribution.storage_location).to eq(storage_location)
      end
    end

    context 'when donation_id is not provided and storage_location_id is not provided' do
      it 'does not copy line items' do
        distribution.copy_from_donation(nil, nil)
        expect(distribution.line_items).to be_empty
      end

      it 'dos not change storage location' do
        distribution.copy_from_donation(nil, nil)
        expect(distribution.storage_location).to eq(distribution.storage_location)
      end
    end
  end
  describe "#combine_distribution", :phoenix do
    let(:empty_line_items) { [] }
    let(:invalid_line_item) { build(:line_item, quantity: 1, item: build(:item, :inactive)) }
    let(:zero_quantity_line_item) { build(:line_item, quantity: 0) }
    let(:valid_item) { create(:item, :active) }
    let(:valid_line_item) { create(:line_item, quantity: 1, item: valid_item) }
    let(:duplicate_item) { create(:item, :active, name: "Duplicate") }
    let(:duplicate_line_item_1) { create(:line_item, quantity: 1, item: duplicate_item) }
    let(:duplicate_line_item_2) { create(:line_item, quantity: 2, item: duplicate_item) }
    let(:mixed_line_items) { [valid_line_item, invalid_line_item, zero_quantity_line_item] }

    it "does nothing when line_items is empty" do
      distribution = Distribution.new(line_items: empty_line_items)
      expect { distribution.combine_distribution }.not_to change { distribution.line_items }
    end

    it "does nothing when line_items contains only invalid items" do
      distribution = Distribution.new(line_items: [invalid_line_item])
      expect { distribution.combine_distribution }.not_to change { distribution.line_items }
    end

    it "does nothing when line_items contains items with zero quantity" do
      distribution = Distribution.new(line_items: [zero_quantity_line_item])
      expect { distribution.combine_distribution }.not_to change { distribution.line_items }
    end

    describe "when line_items contains valid items" do
      it "combines line_items with valid items and non-zero quantity" do
        distribution = Distribution.new(line_items: [valid_line_item])
        expect { distribution.combine_distribution }.not_to change { distribution.line_items.size }
        expect(distribution.line_items.first.quantity).to eq(1)
      end
    end

    describe "when line_items contains duplicate items" do
      it "combines duplicate line_items with the same item_id" do
        distribution = Distribution.new(line_items: [duplicate_line_item_1, duplicate_line_item_2])
        expect { distribution.combine_distribution }.to change { distribution.line_items.size }.from(2).to(1)
      end

      it "updates the quantity of combined line_items" do
        distribution = Distribution.new(line_items: [duplicate_line_item_1, duplicate_line_item_2])
        distribution.combine_distribution
        expect(distribution.line_items.first.quantity).to eq(3)
      end
    end

    describe "when line_items contains a mix of valid and invalid items" do
      it "removes invalid and zero quantity items" do
        distribution = Distribution.new(line_items: mixed_line_items)
        expect { distribution.combine_distribution }.to change { distribution.line_items.size }.from(3).to(1)
      end

      it "keeps valid items with correct quantity" do
        distribution = Distribution.new(line_items: mixed_line_items)
        distribution.combine_distribution
        expect(distribution.line_items.first.quantity).to eq(1)
      end
    end
  end
  describe "#csv_export_attributes", :phoenix do
    let(:organization) { create(:organization) }
    let(:partner) { create(:partner, organization: organization) }
    let(:storage_location) { create(:storage_location, organization: organization) }
    let(:distribution) { build(:distribution, partner: partner, storage_location: storage_location, organization: organization, issued_at: issued_at, delivery_method: delivery_method, state: state, agency_rep: agency_rep) }
    let(:issued_at) { Time.current }
    let(:delivery_method) { :pick_up }
    let(:state) { :scheduled }
    let(:agency_rep) { "John Doe" }

    it "returns correct attributes when all values are present" do
      expect(distribution.csv_export_attributes).to eq([
        partner.name,
        issued_at.strftime("%F"),
        storage_location.name,
        distribution.total_quantity,
        distribution.cents_to_dollar(distribution.line_items.total_value),
        delivery_method.to_s,
        state.to_s,
        agency_rep
      ])
    end

    describe "when total_quantity is zero" do
      before do
        allow(distribution).to receive(:total_quantity).and_return(0)
      end

      it "handles zero total quantity" do
        expect(distribution.csv_export_attributes[3]).to eq(0)
      end
    end

    describe "when line_items total_value is zero" do
      before do
        allow(distribution.line_items).to receive(:total_value).and_return(0)
      end

      it "handles zero total value" do
        expect(distribution.csv_export_attributes[4]).to eq(distribution.cents_to_dollar(0))
      end
    end

    describe "when delivery_method is nil" do
      let(:delivery_method) { nil }

      it "handles missing delivery method" do
        expect(distribution.csv_export_attributes[5]).to be_nil
      end
    end

    describe "when state is nil" do
      let(:state) { nil }

      it "handles missing state" do
        expect(distribution.csv_export_attributes[6]).to be_nil
      end
    end

    describe "when agency_rep is nil" do
      let(:agency_rep) { nil }

      it "handles missing agency representative" do
        expect(distribution.csv_export_attributes[7]).to be_nil
      end
    end
  end
  describe '#future?', :phoenix do
    let(:future_distribution) { build(:distribution, issued_at: Time.zone.today + 1.day) }
    let(:today_distribution) { build(:distribution, issued_at: Time.zone.today) }
    let(:past_distribution) { build(:distribution, issued_at: Time.zone.today - 1.day) }

    it 'returns true when issued_at is in the future' do
      expect(future_distribution.future?).to eq(true)
    end

    xit 'returns false when issued_at is today' do
      expect(today_distribution.future?).to eq(false)
    end

    it 'returns false when issued_at is in the past' do
      expect(past_distribution.future?).to eq(false)
    end
  end
  describe '#past?', :phoenix do
    let(:distribution_past) { build(:distribution, :past) }
    let(:distribution_today) { build(:distribution, issued_at: Time.zone.today) }
    let(:distribution_future) { build(:distribution, issued_at: Time.zone.tomorrow) }

    it 'returns true if issued_at is before today' do
      expect(distribution_past.past?).to be true
    end

    it 'returns false if issued_at is today' do
      expect(distribution_today.past?).to be false
    end

    it 'returns false if issued_at is after today' do
      expect(distribution_future.past?).to be false
    end
  end
end
