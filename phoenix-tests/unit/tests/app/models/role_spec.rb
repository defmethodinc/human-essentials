
require "rails_helper"

RSpec.describe Role do
describe "#title", :phoenix do
  let(:valid_role) { build(:role, name: :org_user) }
  let(:invalid_role) { build(:role, name: :invalid_key) }
  let(:nil_role) { build(:role, name: nil) }

  it "returns the correct title when name is a valid key" do
    expect(valid_role.title).to eq("Organization")
  end

  it "returns nil when name is not a valid key" do
    expect(invalid_role.title).to be_nil
  end

  it "returns nil when name is nil" do
    expect(nil_role.title).to be_nil
  end
end
describe "#resources_for_select", :phoenix do
  let(:titles) do
    {
      org_user: "Organization",
      org_admin: "Organization Admin",
      partner: "Partner",
      super_admin: "Super admin"
    }
  end

  subject { Role.resources_for_select }

  it "does not include the super admin title" do
    expect(subject).not_to have_key("Super admin")
  end

  it "inverts the titles hash correctly" do
    expected_inverted_hash = {
      "Organization" => :org_user,
      "Organization Admin" => :org_admin,
      "Partner" => :partner
    }
    expect(subject).to eq(expected_inverted_hash)
  end

  it "returns a hash with correct titles as keys" do
    expect(subject.keys).to match_array(["Organization", "Organization Admin", "Partner"])
  end

  it "returns a hash with correct roles as values" do
    expect(subject.values).to match_array([:org_user, :org_admin, :partner])
  end
end
end
