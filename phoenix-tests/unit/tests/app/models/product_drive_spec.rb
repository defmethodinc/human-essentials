require "rails_helper"

RSpec.describe ProductDrive, type: :model do
  let(:organization) { create(:organization) }
  let(:product_drive) { create(:product_drive, organization: organization) }
  let(:donation) { create(:donation, product_drive: product_drive) }
  let(:line_item) { create(:line_item, donation: donation) }

  describe "associations" do
    it "belongs to organization" do
      expect(product_drive.organization).to eq(organization)
    end

    it "has many donations" do
      expect(product_drive.donations).to include(donation)
    end

    it "has many product_drive_participants through donations" do
      participant = create(:product_drive_participant, donations: [donation])
      expect(product_drive.product_drive_participants).to include(participant)
    end
  end

  describe "validations" do
    it "validates presence of name" do
      product_drive.name = nil
      expect(product_drive).not_to be_valid
      expect(product_drive.errors[:name]).to include("A name must be chosen.")
    end

    it "validates presence of start_date" do
      product_drive.start_date = nil
      expect(product_drive).not_to be_valid
      expect(product_drive.errors[:start_date]).to include("Please enter a start date.")
    end

    it "validates end_date is after start_date" do
      product_drive.start_date = Date.today
      product_drive.end_date = Date.yesterday
      expect(product_drive).not_to be_valid
      expect(product_drive.errors[:end_date]).to include("End date must be after the start date")
    end
  end

  describe "scopes" do
    describe ".by_name" do
      it "filters by name" do
        create(:product_drive, name: "Drive A")
        create(:product_drive, name: "Drive B")
        expect(ProductDrive.by_name("Drive A").pluck(:name)).to eq(["Drive A"])
      end
    end

    describe ".by_item_category_id" do
      it "filters by item category id" do
        item_category = create(:item_category)
        item = create(:item, item_category: item_category)
        line_item.update(item: item)
        expect(ProductDrive.by_item_category_id(item_category.id)).to include(product_drive)
      end
    end

    describe ".within_date_range" do
      it "filters by date range" do
        create(:product_drive, start_date: Date.today, end_date: Date.tomorrow)
        create(:product_drive, start_date: Date.yesterday, end_date: Date.today)
        expect(ProductDrive.within_date_range("#{Date.today} - #{Date.tomorrow}").count).to eq(1)
      end
    end

    describe ".alphabetized" do
      it "orders by name" do
        create(:product_drive, name: "Drive B")
        create(:product_drive, name: "Drive A")
        expect(ProductDrive.alphabetized.pluck(:name)).to eq(["Drive A", "Drive B"])
      end
    end
  end

  describe "instance methods" do
    describe "#end_date_is_bigger_of_end_date" do
      it "adds error if end_date is before start_date" do
        product_drive.start_date = Date.today
        product_drive.end_date = Date.yesterday
        product_drive.valid?
        expect(product_drive.errors[:end_date]).to include("End date must be after the start date")
      end
    end

    describe "#donation_quantity" do
      it "calculates total donation quantity" do
        create(:line_item, donation: donation, quantity: 5)
        create(:line_item, donation: donation, quantity: 10)
        expect(product_drive.donation_quantity).to eq(15)
      end
    end

    describe "#distinct_items_count" do
      it "counts distinct items" do
        create(:line_item, donation: donation, item: create(:item))
        create(:line_item, donation: donation, item: create(:item))
        expect(product_drive.distinct_items_count).to eq(2)
      end
    end

    describe "#in_kind_value" do
      it "calculates in-kind value" do
        allow(donation).to receive(:value_per_itemizable).and_return(100)
        expect(product_drive.in_kind_value).to eq(100)
      end
    end

    describe "#donation_source_view" do
      it "returns formatted donation source view" do
        expect(product_drive.donation_source_view).to eq("#{product_drive.name} (product drive)")
      end
    end

    describe "#item_quantities_by_name_and_date" do
      it "returns item quantities filtered by date and sorted by name" do
        item1 = create(:item, name: "Item A", organization: organization)
        item2 = create(:item, name: "Item B", organization: organization)
        create(:line_item, donation: donation, item: item1, quantity: 5)
        create(:line_item, donation: donation, item: item2, quantity: 10)
        expect(product_drive.item_quantities_by_name_and_date(Date.today..Date.tomorrow)).to eq([5, 10])
      end
    end

    describe "#donation_quantity_by_date" do
      it "calculates donation quantity by date" do
        create(:line_item, donation: donation, quantity: 5)
        expect(product_drive.donation_quantity_by_date(Date.today..Date.tomorrow)).to eq(5)
      end

      context "with item_category_id" do
        it "filters donation quantity by item category id" do
          item_category = create(:item_category)
          item = create(:item, item_category: item_category)
          line_item.update(item: item, quantity: 5)
          expect(product_drive.donation_quantity_by_date(Date.today..Date.tomorrow, item_category.id)).to eq(5)
        end
      end
    end

    describe "#distinct_items_count_by_date" do
      it "counts distinct items by date" do
        create(:line_item, donation: donation, item: create(:item))
        expect(product_drive.distinct_items_count_by_date(Date.today..Date.tomorrow)).to eq(1)
      end

      context "with item_category_id" do
        it "filters distinct items count by item category id" do
          item_category = create(:item_category)
          item = create(:item, item_category: item_category)
          line_item.update(item: item)
          expect(product_drive.distinct_items_count_by_date(Date.today..Date.tomorrow, item_category.id)).to eq(1)
        end
      end
    end
  end

  describe "class methods" do
    describe ".search_date_range" do
      it "parses date range string into hash" do
        expect(ProductDrive.search_date_range("2023-01-01 - 2023-12-31")).to eq({ start_date: "2023-01-01", end_date: "2023-12-31" })
      end
    end
  end
end
