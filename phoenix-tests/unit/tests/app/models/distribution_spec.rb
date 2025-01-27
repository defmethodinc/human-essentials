require "rails_helper"

RSpec.describe Distribution, type: :model do
  let(:organization) { create(:organization) }
  let(:partner) { create(:partner, organization: organization) }
  let(:storage_location) { create(:storage_location, organization: organization) }
  let(:distribution) { create(:distribution, organization: organization, partner: partner, storage_location: storage_location) }

  describe "associations" do
    it "belongs to storage_location" do
      expect(distribution.storage_location).to eq(storage_location)
    end

    it "belongs to partner" do
      expect(distribution.partner).to eq(partner)
    end

    it "belongs to organization" do
      expect(distribution.organization).to eq(organization)
    end

    it "has one request" do
      request = create(:request, distribution: distribution)
      expect(distribution.request).to eq(request)
    end
  end

  describe "validations" do
    it "validates presence of storage_location" do
      distribution.storage_location = nil
      expect(distribution).not_to be_valid
    end

    it "validates presence of partner" do
      distribution.partner = nil
      expect(distribution).not_to be_valid
    end

    it "validates presence of organization" do
      distribution.organization = nil
      expect(distribution).not_to be_valid
    end

    it "validates presence of delivery_method" do
      distribution.delivery_method = nil
      expect(distribution).not_to be_valid
    end

    it "validates line_items_quantity_is_positive" do
      allow(distribution).to receive(:line_items_quantity_is_at_least).with(1)
      distribution.valid?
      expect(distribution).to have_received(:line_items_quantity_is_at_least).with(1)
    end

    it "validates numericality of shipping_cost if shipped" do
      distribution.delivery_method = "shipped"
      distribution.shipping_cost = -1
      expect(distribution).not_to be_valid
    end
  end

  describe "callbacks" do
    it "calls combine_distribution before save" do
      expect(distribution).to receive(:combine_distribution)
      distribution.save
    end

    it "calls reset_shipping_cost before save" do
      distribution.delivery_method = "pick_up"
      distribution.shipping_cost = 10
      distribution.save
      expect(distribution.shipping_cost).to be_nil
    end
  end

  describe "scopes" do
    it ".active returns active distributions" do
      active_distribution = create(:distribution, organization: organization)
      expect(Distribution.active).to include(active_distribution)
    end

    it ".by_item_id filters by item_id" do
      item = create(:item)
      distribution.line_items.create(item: item, quantity: 1)
      expect(Distribution.by_item_id(item.id)).to include(distribution)
    end

    it ".by_item_category_id filters by item_category_id" do
      item_category = create(:item_category)
      item = create(:item, item_category: item_category)
      distribution.line_items.create(item: item, quantity: 1)
      expect(Distribution.by_item_category_id(item_category.id)).to include(distribution)
    end

    it ".by_partner filters by partner" do
      expect(Distribution.by_partner(partner.id)).to include(distribution)
    end

    it ".by_location filters by storage_location" do
      expect(Distribution.by_location(storage_location.id)).to include(distribution)
    end

    it ".by_state filters by state" do
      expect(Distribution.by_state("scheduled")).to include(distribution)
    end

    it ".recent returns recent distributions" do
      expect(Distribution.recent).to include(distribution)
    end

    it ".future returns future distributions" do
      distribution.update(issued_at: Time.zone.tomorrow)
      expect(Distribution.future).to include(distribution)
    end

    it ".during filters distributions during a range" do
      range = Time.zone.today..Time.zone.tomorrow
      distribution.update(issued_at: Time.zone.today)
      expect(Distribution.during(range)).to include(distribution)
    end

    it ".for_csv_export filters for CSV export" do
      expect(Distribution.for_csv_export(organization)).to include(distribution)
    end

    it ".apply_filters applies given filters" do
      filters = { partner_id: partner.id }
      expect(Distribution.apply_filters(filters, nil)).to include(distribution)
    end

    it ".this_week returns distributions for this week" do
      distribution.update(issued_at: Time.zone.today)
      expect(Distribution.this_week).to include(distribution)
    end
  end

  describe "instance methods" do
    describe "#distributed_at" do
      it "returns formatted date or datetime" do
        distribution.update(issued_at: Time.zone.now)
        expect(distribution.distributed_at).to be_present
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
        expect(distribution.line_items.first.item_id).to eq(line_item.item_id)
      end
    end

    describe "#copy_from_donation" do
      it "copies from a donation and sets storage location" do
        donation = create(:donation)
        distribution.copy_from_donation(donation.id, storage_location.id)
        expect(distribution.storage_location).to eq(storage_location)
      end
    end

    describe "#initialize_request_items" do
      it "initializes request items with zero quantity if not present" do
        request = create(:request, distribution: distribution)
        distribution.initialize_request_items
        expect(distribution.line_items.any? { |li| li.quantity == 0 }).to be true
      end
    end

    describe "#copy_from_request" do
      it "copies from a request and sets attributes" do
        request = create(:request)
        distribution.copy_from_request(request.id)
        expect(distribution.request).to eq(request)
        expect(distribution.organization_id).to eq(request.organization_id)
        expect(distribution.partner_id).to eq(request.partner_id)
      end
    end

    describe "#combine_distribution" do
      it "combines line items" do
        expect(distribution.line_items).to receive(:combine!)
        distribution.combine_distribution
      end
    end

    describe "#csv_export_attributes" do
      it "returns attributes for CSV export" do
        expect(distribution.csv_export_attributes).to include(distribution.partner.name)
      end
    end

    describe "#future?" do
      it "returns true if issued_at is in the future" do
        distribution.update(issued_at: Time.zone.tomorrow)
        expect(distribution.future?).to be true
      end
    end

    describe "#past?" do
      it "returns true if issued_at is in the past" do
        distribution.update(issued_at: Time.zone.yesterday)
        expect(distribution.past?).to be true
      end
    end
  end
end
