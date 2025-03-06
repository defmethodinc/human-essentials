
require "rails_helper"

RSpec.describe County do
describe "#in_category_name_order", :phoenix do
  let(:county_us) { create(:county, category: "US_County", name: "Alpha") }
  let(:county_foreign) { create(:county, category: "Foreign_County", name: "Beta") }
  let(:county_same_category_1) { create(:county, category: "US_County", name: "Beta") }
  let(:county_same_category_2) { create(:county, category: "US_County", name: "Alpha") }
  let(:county_unknown_category) { create(:county, category: "Unknown_County", name: "Gamma") }

  before do
    county_us
    county_foreign
    county_same_category_1
    county_same_category_2
    county_unknown_category
  end

  it "orders counties by category according to SORT_ORDER" do
    sorted_counties = County.in_category_name_order
    expect(sorted_counties.map(&:category)).to eq(["US_County", "US_County", "US_County", "Foreign_County", "Unknown_County"])
  end

  it "orders counties with the same category by name" do
    sorted_counties = County.in_category_name_order
    expect(sorted_counties.map(&:name)).to eq(["Alpha", "Alpha", "Beta", "Beta", "Gamma"])
  end

  describe "when there are no counties" do
    it "returns an empty array" do
      County.delete_all
      expect(County.in_category_name_order).to eq([])
    end
  end

  describe "when all counties have the same category" do
    before do
      County.delete_all
      create(:county, category: "US_County", name: "Gamma")
      create(:county, category: "US_County", name: "Alpha")
      create(:county, category: "US_County", name: "Beta")
    end

    it "orders counties by name only" do
      sorted_counties = County.in_category_name_order
      expect(sorted_counties.map(&:name)).to eq(["Alpha", "Beta", "Gamma"])
    end
  end

  describe "when categories are not in SORT_ORDER" do
    it "places them after the known categories" do
      sorted_counties = County.in_category_name_order
      expect(sorted_counties.last.category).to eq("Unknown_County")
    end
  end
end
end
