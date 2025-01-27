require "rails_helper"

RSpec.describe Distribution, type: :model do
  let(:organization) { create(:organization) }
  let(:partner) { create(:partner) }
  let(:storage_location) { create(:storage_location) }
  let(:distribution) { build(:distribution, organization: organization, partner: partner, storage_location: storage_location) }

  describe "validations" do
    it "validates presence of storage_location" do
      distribution.storage_location = nil
      expect(distribution).not_to be_valid
      expect(distribution.errors[:storage_location]).to include("can't be blank")
    end

    it "validates presence of partner" do
      distribution.partner = nil
      expect(distribution).not_to be_valid
      expect(distribution.errors[:partner]).to include("can't be blank")
    end

    it "validates presence of organization" do
      distribution.organization = nil
      expect(distribution).not_to be_valid
      expect(distribution.errors[:organization]).to include("can't be blank")
    end

    it "validates presence of delivery_method" do
      distribution.delivery_method = nil
      expect(distribution).not_to be_valid
      expect(distribution.errors[:delivery_method]).to include("can't be blank")
    end

    context "when shipped" do
      it "validates numericality of shipping_cost" do
        distribution.delivery_method = "shipped"
        distribution.shipping_cost = -1
        expect(distribution).not_to be_valid
        expect(distribution.errors[:shipping_cost]).to include("must be greater than or equal to 0")
      end
    end
  end

  describe "callbacks" do
    it "combines distribution before save" do
      expect(distribution).to receive(:combine_distribution)
      distribution.save
    end

    it "resets shipping cost before save if not shipped" do
      distribution.delivery_method = "pick_up"
      distribution.shipping_cost = 10.0
      distribution.save
      expect(distribution.shipping_cost).to be_nil
    end
  end

  describe "enums" do
    it "has the correct state values" do
      expect(Distribution.states).to eq({ "scheduled" => 5, "complete" => 10 })
    end

    it "has the correct delivery_method values" do
      expect(Distribution.delivery_methods).to eq({ "pick_up" => 0, "delivery" => 1, "shipped" => 2 })
    end
  end

  describe "scopes" do
    describe ".active" do
      it "returns active distributions" do
        active_distribution = create(:distribution, :with_items, organization: organization)
        inactive_distribution = create(:distribution, organization: organization)
        expect(Distribution.active).to include(active_distribution)
        expect(Distribution.active).not_to include(inactive_distribution)
      end
    end

    describe ".by_item_id" do
      it "filters distributions by item_id" do
        item = create(:item)
        distribution_with_item = create(:distribution, :with_items, items: [item], organization: organization)
        distribution_without_item = create(:distribution, organization: organization)
        expect(Distribution.by_item_id(item.id)).to include(distribution_with_item)
        expect(Distribution.by_item_id(item.id)).not_to include(distribution_without_item)
      end
    end

    describe ".by_item_category_id" do
      it "filters distributions by item_category_id" do
        item_category = create(:item_category)
        item = create(:item, item_category: item_category)
        distribution_with_category = create(:distribution, :with_items, items: [item], organization: organization)
        distribution_without_category = create(:distribution, organization: organization)
        expect(Distribution.by_item_category_id(item_category.id)).to include(distribution_with_category)
        expect(Distribution.by_item_category_id(item_category.id)).not_to include(distribution_without_category)
      end
    end

    describe ".by_partner" do
      it "filters distributions by partner" do
        distribution_with_partner = create(:distribution, partner: partner, organization: organization)
        distribution_without_partner = create(:distribution, organization: organization)
        expect(Distribution.by_partner(partner.id)).to include(distribution_with_partner)
        expect(Distribution.by_partner(partner.id)).not_to include(distribution_without_partner)
      end
    end

    describe ".by_location" do
      it "filters distributions by storage_location" do
        distribution_with_location = create(:distribution, storage_location: storage_location, organization: organization)
        distribution_without_location = create(:distribution, organization: organization)
        expect(Distribution.by_location(storage_location.id)).to include(distribution_with_location)
        expect(Distribution.by_location(storage_location.id)).not_to include(distribution_without_location)
      end
    end

    describe ".by_state" do
      it "filters distributions by state" do
        scheduled_distribution = create(:distribution, state: :scheduled, organization: organization)
        complete_distribution = create(:distribution, state: :complete, organization: organization)
        expect(Distribution.by_state("scheduled")).to include(scheduled_distribution)
        expect(Distribution.by_state("scheduled")).not_to include(complete_distribution)
      end
    end

    describe ".recent" do
      it "returns recent distributions" do
        older_distribution = create(:distribution, issued_at: 2.days.ago, organization: organization)
        recent_distribution = create(:distribution, issued_at: 1.day.ago, organization: organization)
        expect(Distribution.recent).to include(recent_distribution)
        expect(Distribution.recent).not_to include(older_distribution)
      end
    end

    describe ".future" do
      it "returns future distributions" do
        future_distribution = create(:distribution, issued_at: 1.day.from_now, organization: organization)
        past_distribution = create(:distribution, issued_at: 1.day.ago, organization: organization)
        expect(Distribution.future).to include(future_distribution)
        expect(Distribution.future).not_to include(past_distribution)
      end
    end

    describe ".during" do
      it "returns distributions during a specific range" do
        distribution_in_range = create(:distribution, issued_at: 2.days.ago, organization: organization)
        distribution_out_of_range = create(:distribution, issued_at: 10.days.ago, organization: organization)
        expect(Distribution.during(3.days.ago..1.day.ago)).to include(distribution_in_range)
        expect(Distribution.during(3.days.ago..1.day.ago)).not_to include(distribution_out_of_range)
      end
    end

    describe ".for_csv_export" do
      it "returns distributions for CSV export" do
        distribution = create(:distribution, organization: organization)
        expect(Distribution.for_csv_export(organization)).to include(distribution)
      end
    end

    describe ".apply_filters" do
      it "applies filters to distributions" do
        distribution = create(:distribution, organization: organization, partner: partner)
        expect(Distribution.apply_filters({ partner_id: partner.id }, nil)).to include(distribution)
      end
    end

    describe ".this_week" do
      it "returns distributions for this week" do
        this_week_distribution = create(:distribution, issued_at: Time.zone.today, organization: organization)
        last_week_distribution = create(:distribution, issued_at: 1.week.ago, organization: organization)
        expect(Distribution.this_week).to include(this_week_distribution)
        expect(Distribution.this_week).not_to include(last_week_distribution)
      end
    end
  end

  describe "instance methods" do
    describe "#distributed_at" do
      it "returns formatted issued_at" do
        distribution.issued_at = Time.zone.now.midnight
        expect(distribution.distributed_at).to eq(distribution.issued_at.to_fs(:distribution_date))
      end
    end

    describe "#combine_duplicates" do
      it "combines duplicate line items" do
        expect(distribution.line_items).to receive(:combine!)
        distribution.combine_duplicates
      end
    end

    describe "#copy_line_items" do
      it "copies line items from a donation" do
        donation = create(:donation)
        line_item = create(:line_item, itemizable: donation)
        distribution.copy_line_items(donation.id)
        expect(distribution.line_items.map(&:item_id)).to include(line_item.item_id)
      end
    end

    describe "#copy_from_donation" do
      it "copies from a donation and sets storage location" do
        donation = create(:donation)
        storage_location = create(:storage_location)
        distribution.copy_from_donation(donation.id, storage_location.id)
        expect(distribution.storage_location).to eq(storage_location)
      end
    end

    describe "#initialize_request_items" do
      it "initializes request items with zero quantity" do
        request = create(:request, organization: organization)
        distribution.request = request
        distribution.initialize_request_items
        expect(distribution.line_items.map(&:quantity)).to include(0)
      end
    end

    describe "#copy_from_request" do
      it "copies from a request and sets attributes" do
        request = create(:request, organization: organization, partner: partner)
        distribution.copy_from_request(request.id)
        expect(distribution.request).to eq(request)
        expect(distribution.organization_id).to eq(request.organization_id)
        expect(distribution.partner_id).to eq(request.partner_id)
      end
    end

    describe "#csv_export_attributes" do
      it "returns attributes for CSV export" do
        distribution.save
        expect(distribution.csv_export_attributes).to include(
          distribution.partner.name,
          distribution.issued_at.strftime("%F"),
          distribution.storage_location.name
        )
      end
    end

    describe "#future?" do
      it "returns true if issued_at is in the future" do
        distribution.issued_at = 1.day.from_now
        expect(distribution.future?).to be true
      end
    end

    describe "#past?" do
      it "returns true if issued_at is in the past" do
        distribution.issued_at = 1.day.ago
        expect(distribution.past?).to be true
      end
    end
  end
end
