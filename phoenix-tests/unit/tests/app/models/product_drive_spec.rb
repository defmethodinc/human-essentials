require "rails_helper"

RSpec.describe ProductDrive, type: :model do
  let(:organization) { create(:organization) }
  let(:product_drive) { create(:product_drive, organization: organization) }
  let(:donation) { create(:donation, product_drive: product_drive) }
  let(:line_item) { create(:line_item, itemizable: donation) }

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
        product_drive1 = create(:product_drive, name: "Drive A")
        product_drive2 = create(:product_drive, name: "Drive B")
        expect(ProductDrive.by_name("Drive A")).to include(product_drive1)
        expect(ProductDrive.by_name("Drive A")).not_to include(product_drive2)
      end
    end

    describe ".by_item_category_id" do
      it "filters by item category id" do
        category = create(:item_category)
        item = create(:item, item_category: category)
        line_item.update(item: item)
        expect(ProductDrive.by_item_category_id(category.id)).to include(product_drive)
      end
    end

    describe ".within_date_range" do
      it "filters by date range" do
        product_drive1 = create(:product_drive, start_date: Date.today - 5, end_date: Date.today + 5)
        product_drive2 = create(:product_drive, start_date: Date.today + 10, end_date: Date.today + 15)
        range = "#{Date.today - 1} - #{Date.today + 1}"
        expect(ProductDrive.within_date_range(range)).to include(product_drive1)
        expect(ProductDrive.within_date_range(range)).not_to include(product_drive2)
      end
    end

    describe ".alphabetized" do
      it "orders by name" do
        product_drive1 = create(:product_drive, name: "B Drive")
        product_drive2 = create(:product_drive, name: "A Drive")
        expect(ProductDrive.alphabetized).to eq([product_drive2, product_drive1])
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
        line_item.update(quantity: 5)
        expect(product_drive.donation_quantity).to eq(5)
      end
    end

    describe "#distinct_items_count" do
      it "counts distinct items" do
        item1 = create(:item)
        item2 = create(:item)
        create(:line_item, itemizable: donation, item: item1)
        create(:line_item, itemizable: donation, item: item2)
        expect(product_drive.distinct_items_count).to eq(2)
      end
    end

    describe "#in_kind_value" do
      it "calculates in-kind value" do
        donation.update(value_per_itemizable: 100)
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
        item1 = create(:item, name: "Item A")
        item2 = create(:item, name: "Item B")
        create(:line_item, itemizable: donation, item: item1, quantity: 3)
        create(:line_item, itemizable: donation, item: item2, quantity: 2)
        date_range = (Date.today - 1)..(Date.today + 1)
        expect(product_drive.item_quantities_by_name_and_date(date_range)).to eq([3, 2])
      end
    end

    describe "#donation_quantity_by_date" do
      it "calculates donation quantity by date" do
        line_item.update(quantity: 5)
        date_range = (Date.today - 1)..(Date.today + 1)
        expect(product_drive.donation_quantity_by_date(date_range)).to eq(5)
      end

      context "with item_category_id" do
        it "filters donation quantity by item category id" do
          category = create(:item_category)
          item = create(:item, item_category: category)
          line_item.update(item: item, quantity: 5)
          date_range = (Date.today - 1)..(Date.today + 1)
          expect(product_drive.donation_quantity_by_date(date_range, category.id)).to eq(5)
        end
      end
    end

    describe "#distinct_items_count_by_date" do
      it "counts distinct items by date" do
        item1 = create(:item)
        item2 = create(:item)
        create(:line_item, itemizable: donation, item: item1)
        create(:line_item, itemizable: donation, item: item2)
        date_range = (Date.today - 1)..(Date.today + 1)
        expect(product_drive.distinct_items_count_by_date(date_range)).to eq(2)
      end

      context "with item_category_id" do
        it "filters distinct items count by item category id" do
          category = create(:item_category)
          item = create(:item, item_category: category)
          create(:line_item, itemizable: donation, item: item)
          date_range = (Date.today - 1)..(Date.today + 1)
          expect(product_drive.distinct_items_count_by_date(date_range, category.id)).to eq(1)
        end
      end
    end
  end

  describe "class methods" do
    describe ".search_date_range" do
      it "parses date range string into hash" do
        dates = "2023-01-01 - 2023-12-31"
        expected = { start_date: "2023-01-01", end_date: "2023-12-31" }
        expect(ProductDrive.search_date_range(dates)).to eq(expected)
      end
    end
  end
end
