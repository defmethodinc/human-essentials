
require "rails_helper"

RSpec.describe Partner do
describe "#agency_info", :phoenix do
  let(:partner) { build(:partner) }
  let(:profile) { build(:partner_profile, partner: partner, agency_type: agency_type, address1: address1, address2: address2, city: city, state: state, zip_code: zip_code, website: website, other_agency_type: other_agency_type) }
  let(:agency_type) { nil }
  let(:address1) { "123 Main St" }
  let(:address2) { "Apt 4" }
  let(:city) { "Metropolis" }
  let(:state) { "NY" }
  let(:zip_code) { "12345" }
  let(:website) { "http://example.com" }
  let(:other_agency_type) { "Custom Agency" }

  before do
    allow(partner).to receive(:profile).and_return(profile)
  end

  it "returns cached @agency_info if already set" do
    partner.instance_variable_set(:@agency_info, { cached: true })
    expect(partner.agency_info).to eq({ cached: true })
  end

  context "when profile.agency_type is nil" do
    let(:agency_type) { nil }

    it "returns nil for agency_type" do
      expect(partner.agency_info[:agency_type]).to be_nil
    end
  end

  context "when profile.agency_type is :other" do
    let(:agency_type) { :other }

    it "includes other_agency_type in agency_type" do
      expect(partner.agency_info[:agency_type]).to eq("Other: Custom Agency")
    end
  end

  context "when profile.agency_type is not :other" do
    let(:agency_type) { :government }

    it "translates agency_type without other_agency_type" do
      expect(partner.agency_info[:agency_type]).to eq("Government")
    end
  end

  context "when profile.address1 and/or profile.address2 are present" do
    let(:address1) { "123 Main St" }
    let(:address2) { "Apt 4" }

    it "joins address1 and address2 correctly" do
      expect(partner.agency_info[:address]).to eq("123 Main St, Apt 4")
    end
  end

  context "when profile.address1 and profile.address2 are both absent" do
    let(:address1) { nil }
    let(:address2) { nil }

    it "returns empty string for address when both are absent" do
      expect(partner.agency_info[:address]).to eq("")
    end
  end

  it "returns correct city" do
    expect(partner.agency_info[:city]).to eq("Metropolis")
  end

  it "returns correct state" do
    expect(partner.agency_info[:state]).to eq("NY")
  end

  it "returns correct zip_code" do
    expect(partner.agency_info[:zip_code]).to eq("12345")
  end

  it "returns correct website" do
    expect(partner.agency_info[:website]).to eq("http://example.com")
  end
end
describe '#approvable?', :phoenix do
  let(:partner_invited) { build(:partner, invited: true, awaiting_review: false) }
  let(:partner_awaiting_review) { build(:partner, invited: false, awaiting_review: true) }
  let(:partner_both_true) { build(:partner, invited: true, awaiting_review: true) }
  let(:partner_both_false) { build(:partner, invited: false, awaiting_review: false) }

  it 'returns true when invited? is true and awaiting_review? is false' do
    expect(partner_invited.approvable?).to be true
  end

  it 'returns true when invited? is false and awaiting_review? is true' do
    expect(partner_awaiting_review.approvable?).to be true
  end

  it 'returns true when both invited? and awaiting_review? are true' do
    expect(partner_both_true.approvable?).to be true
  end

  it 'returns false when both invited? and awaiting_review? are false' do
    expect(partner_both_false.approvable?).to be false
  end
end
describe '#deletable?', :phoenix do
  let(:partner) { build(:partner, status: partner_status) }
  let(:partner_status) { :uninvited }
  let(:distributions) { [] }
  let(:requests) { [] }
  let(:users) { [] }

  before do
    allow(partner).to receive(:distributions).and_return(distributions)
    allow(partner).to receive(:requests).and_return(requests)
    allow(partner).to receive(:users).and_return(users)
  end

  it 'returns true when uninvited, no distributions, no requests, and no users' do
    expect(partner.deletable?).to be true
  end

  context 'when invited' do
    let(:partner_status) { :approved }

    it 'returns false even if no distributions, requests, or users' do
      expect(partner.deletable?).to be false
    end
  end

  context 'when there are distributions' do
    let(:distributions) { [build(:distribution)] }

    it 'returns false' do
      expect(partner.deletable?).to be false
    end
  end

  context 'when there are requests' do
    let(:requests) { [build(:request)] }

    it 'returns false' do
      expect(partner.deletable?).to be false
    end
  end

  context 'when there are users' do
    let(:users) { [build(:user)] }

    it 'returns false' do
      expect(partner.deletable?).to be false
    end
  end

  context 'when users is nil' do
    let(:users) { nil }

    it 'returns false' do
      expect(partner.deletable?).to be false
    end
  end
end
describe "#display_status", :phoenix do
  let(:partner_awaiting_review) { build(:partner, :awaiting_review) }
  let(:partner_uninvited) { build(:partner, :uninvited) }
  let(:partner_approved) { build(:partner, :approved) }
  let(:partner_other_status) { build(:partner, status: :some_other_status) }

  it "returns 'Submitted' when status is :awaiting_review" do
    expect(partner_awaiting_review.display_status).to eq('Submitted')
  end

  it "returns 'Pending' when status is :uninvited" do
    expect(partner_uninvited.display_status).to eq('Pending')
  end

  it "returns 'Verified' when status is :approved" do
    expect(partner_approved.display_status).to eq('Verified')
  end

  it "titleizes the status for any other status" do
    expect(partner_other_status.display_status).to eq('Some Other Status')
  end
end
describe "#impact_metrics", :phoenix do
  let(:partner) { create(:partner) }
  let!(:family1) { create(:partners_family, partner: partner, guardian_zip_code: '12345') }
  let!(:family2) { create(:partners_family, partner: partner, guardian_zip_code: '67890') }
  let!(:child1) { create(:partners_child, family: family1) }
  let!(:child2) { create(:partners_child, family: family2) }

  it "returns the correct hash structure" do
    expect(partner.impact_metrics).to eq({
      families_served: 2,
      children_served: 2,
      family_zipcodes: 2,
      family_zipcodes_list: ['12345', '67890']
    })
  end

  it "returns correct families_served count" do
    expect(partner.impact_metrics[:families_served]).to eq(2)
  end

  it "returns correct children_served count" do
    expect(partner.impact_metrics[:children_served]).to eq(2)
  end

  it "returns correct family_zipcodes count" do
    expect(partner.impact_metrics[:family_zipcodes]).to eq(2)
  end

  it "returns correct family_zipcodes list" do
    expect(partner.impact_metrics[:family_zipcodes_list]).to match_array(['12345', '67890'])
  end

  describe "when counts are zero" do
    let(:partner) { create(:partner) }

    it "handles zero families_served count" do
      expect(partner.impact_metrics[:families_served]).to eq(0)
    end

    it "handles zero children_served count" do
      expect(partner.impact_metrics[:children_served]).to eq(0)
    end

    it "handles zero family_zipcodes count" do
      expect(partner.impact_metrics[:family_zipcodes]).to eq(0)
    end
  end

  describe "when lists are empty" do
    let(:partner) { create(:partner) }

    it "handles empty family_zipcodes list" do
      expect(partner.impact_metrics[:family_zipcodes_list]).to eq([])
    end
  end

  describe "error handling" do
    before do
      allow(partner).to receive(:families_served_count).and_raise(StandardError)
      allow(partner).to receive(:children_served_count).and_raise(StandardError)
      allow(partner).to receive(:family_zipcodes_count).and_raise(StandardError)
      allow(partner).to receive(:family_zipcodes_list).and_raise(StandardError)
    end

    it "handles errors in families_served_count" do
      expect { partner.impact_metrics[:families_served] }.to raise_error(StandardError)
    end

    it "handles errors in children_served_count" do
      expect { partner.impact_metrics[:children_served] }.to raise_error(StandardError)
    end

    it "handles errors in family_zipcodes_count" do
      expect { partner.impact_metrics[:family_zipcodes] }.to raise_error(StandardError)
    end

    it "handles errors in family_zipcodes_list" do
      expect { partner.impact_metrics[:family_zipcodes_list] }.to raise_error(StandardError)
    end
  end
end
describe "#import_csv", :phoenix do
  let(:organization) { create(:organization) }
  let(:valid_csv) { CSV.generate { |csv| csv << %w[name email]; csv << ["Partner Name", "partner@example.com"] } }
  let(:invalid_csv) { CSV.generate { |csv| csv << %w[name email]; csv << [nil, "partner@example.com"] } }
  let(:empty_csv) { CSV.generate { |csv| csv << [] } }

  it "imports CSV successfully" do
    errors = Partner.import_csv(valid_csv, organization.id)
    expect(errors).to be_empty
  end

  it "creates a partner with correct name" do
    Partner.import_csv(valid_csv, organization.id)
    expect(Partner.last.name).to eq("Partner Name")
  end

  describe "when partner creation fails" do
    before do
      allow_any_instance_of(PartnerCreateService).to receive(:call).and_wrap_original do |m, *args|
        partner = m.receiver.partner
        partner.errors.add(:base, "Creation error")
      end
    end

    it "returns error message" do
      errors = Partner.import_csv(valid_csv, organization.id)
      expect(errors).to include("Partner Name: Creation error")
    end
  end

  describe "with invalid CSV data" do
    it "returns error for missing name" do
      errors = Partner.import_csv(invalid_csv, organization.id)
      expect(errors).to include(": Name can't be blank")
    end
  end

  describe "with empty CSV" do
    it "returns no errors" do
      errors = Partner.import_csv(empty_csv, organization.id)
      expect(errors).to be_empty
    end
  end

  describe "when organization is not found" do
    it "raises ActiveRecord::RecordNotFound" do
      expect { Partner.import_csv(valid_csv, -1) }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
describe "#partials_to_show", :phoenix do
  let(:organization) { build(:organization) }
  let(:partner) { build(:partner, organization: organization) }
  let(:partner_form_fields) { nil }

  before do
    allow(organization).to receive(:partner_form_fields).and_return(partner_form_fields)
  end

  context "when partner_form_fields is present" do
    let(:partner_form_fields) { ["field1", "field2"] }

    it "returns the partner_form_fields" do
      expect(partner.partials_to_show).to eq(partner_form_fields)
    end
  end

  context "when partner_form_fields is not present" do
    it "returns ALL_PARTIALS" do
      expect(partner.partials_to_show).to eq(ALL_PARTIALS)
    end
  end
end
describe '#primary_user', :phoenix do
  let(:partner) { create(:partner) }

  context 'when there are no users' do
    it 'returns nil' do
      expect(partner.primary_user).to be_nil
    end
  end

  context 'when there is one user' do
    let!(:user) { create(:user, partner: partner) }

    it 'returns the only user' do
      expect(partner.primary_user).to eq(user)
    end
  end

  context 'when there are multiple users with different creation dates' do
    let!(:user1) { create(:user, partner: partner, created_at: 2.days.ago) }
    let!(:user2) { create(:user, partner: partner, created_at: 1.day.ago) }
    let!(:user3) { create(:user, partner: partner, created_at: 3.days.ago) }

    it 'returns the first created user' do
      expect(partner.primary_user).to eq(user3)
    end
  end

  context 'when all users have the same creation date' do
    let!(:user1) { create(:user, partner: partner, created_at: 1.day.ago) }
    let!(:user2) { create(:user, partner: partner, created_at: 1.day.ago) }
    let!(:user3) { create(:user, partner: partner, created_at: 1.day.ago) }

    it 'returns the first user' do
      expect(partner.primary_user).to eq(user1)
    end
  end
end
describe "#quantity_year_to_date", :phoenix do
  let(:partner) { create(:partner) }
  let(:distribution_with_no_line_items) { create(:distribution, partner: partner, issued_at: Time.zone.today.beginning_of_year + 1.day) }
  let(:distribution_with_zero_quantity_line_items) do
    create(:distribution, :with_items, partner: partner, issued_at: Time.zone.today.beginning_of_year + 1.day, item_quantity: 0)
  end
  let(:distribution_with_line_items) do
    create(:distribution, :with_items, partner: partner, issued_at: Time.zone.today.beginning_of_year + 1.day, item_quantity: 5)
  end

  it "returns 0 when there are no distributions" do
    expect(partner.quantity_year_to_date).to eq(0)
  end

  it "returns 0 when distributions have no line items" do
    distribution_with_no_line_items
    expect(partner.quantity_year_to_date).to eq(0)
  end

  it "returns 0 when all line items have zero quantity" do
    distribution_with_zero_quantity_line_items
    expect(partner.quantity_year_to_date).to eq(0)
  end

  it "sums quantities of line items correctly" do
    distribution_with_line_items
    expect(partner.quantity_year_to_date).to eq(5)
  end

  describe "at the beginning of the year" do
    let(:distribution_on_first_day) { create(:distribution, :with_items, partner: partner, issued_at: Time.zone.today.beginning_of_year, item_quantity: 10) }

    it "includes distributions from the first day of the year" do
      distribution_on_first_day
      expect(partner.quantity_year_to_date).to eq(10)
    end
  end

  describe "during a leap year" do
    let(:leap_year_distribution) { create(:distribution, :with_items, partner: partner, issued_at: Date.new(2020, 2, 29), item_quantity: 20) }

    it "handles leap year correctly" do
      leap_year_distribution
      expect(partner.quantity_year_to_date).to eq(20)
    end
  end
end
describe '#contact_person', :phoenix do
  let(:partner) { build(:partner) }
  let(:profile) { build(:partner_profile, partner: partner) }

  before do
    allow(partner).to receive(:profile).and_return(profile)
  end

  it 'returns the cached contact person if already set' do
    contact_person = { name: 'John Doe', email: 'john.doe@example.com', phone: '1234567890' }
    partner.instance_variable_set(:@contact_person, contact_person)
    expect(partner.contact_person).to eq(contact_person)
  end

  context 'when @contact_person is not set' do
    it 'returns a contact person with all profile attributes present' do
      allow(profile).to receive(:primary_contact_name).and_return('Jane Doe')
      allow(profile).to receive(:primary_contact_email).and_return('jane.doe@example.com')
      allow(profile).to receive(:primary_contact_phone).and_return('0987654321')

      expected_contact_person = {
        name: 'Jane Doe',
        email: 'jane.doe@example.com',
        phone: '0987654321'
      }

      expect(partner.contact_person).to eq(expected_contact_person)
    end

    it 'returns a contact person with mobile phone if primary phone is absent' do
      allow(profile).to receive(:primary_contact_phone).and_return(nil)
      allow(profile).to receive(:primary_contact_mobile).and_return('1122334455')

      expected_contact_person = {
        name: profile.primary_contact_name,
        email: profile.primary_contact_email,
        phone: '1122334455'
      }

      expect(partner.contact_person).to eq(expected_contact_person)
    end

    it 'returns a contact person with no phone if both phones are absent' do
      allow(profile).to receive(:primary_contact_phone).and_return(nil)
      allow(profile).to receive(:primary_contact_mobile).and_return(nil)

      expected_contact_person = {
        name: profile.primary_contact_name,
        email: profile.primary_contact_email,
        phone: nil
      }

      expect(partner.contact_person).to eq(expected_contact_person)
    end

    it 'returns a contact person with no name if primary contact name is absent' do
      allow(profile).to receive(:primary_contact_name).and_return(nil)

      expected_contact_person = {
        name: nil,
        email: profile.primary_contact_email,
        phone: profile.primary_contact_phone || profile.primary_contact_mobile
      }

      expect(partner.contact_person).to eq(expected_contact_person)
    end

    it 'returns a contact person with no email if primary contact email is absent' do
      allow(profile).to receive(:primary_contact_email).and_return(nil)

      expected_contact_person = {
        name: profile.primary_contact_name,
        email: nil,
        phone: profile.primary_contact_phone || profile.primary_contact_mobile
      }

      expect(partner.contact_person).to eq(expected_contact_person)
    end
  end
end
describe '#primary_user', :phoenix do
  let(:partner) { create(:partner) }

  context 'when there are no users' do
    it 'returns nil' do
      expect(partner.primary_user).to be_nil
    end
  end

  context 'when there is one user' do
    let!(:user) { create(:user, partner: partner) }

    it 'returns the only user' do
      expect(partner.primary_user).to eq(user)
    end
  end

  context 'when there are multiple users with different creation dates' do
    let!(:user1) { create(:user, partner: partner, created_at: 2.days.ago) }
    let!(:user2) { create(:user, partner: partner, created_at: 1.day.ago) }
    let!(:user3) { create(:user, partner: partner, created_at: 3.days.ago) }

    it 'returns the first created user' do
      expect(partner.primary_user).to eq(user3)
    end
  end

  context 'when all users have the same creation date' do
    let!(:user1) { create(:user, partner: partner, created_at: 1.day.ago) }
    let!(:user2) { create(:user, partner: partner, created_at: 1.day.ago) }
    let!(:user3) { create(:user, partner: partner, created_at: 1.day.ago) }

    it 'returns the first user' do
      expect(partner.primary_user).to eq(user1)
    end
  end
end
describe '#deletable?', :phoenix do
  let(:partner) { build(:partner, status: partner_status) }
  let(:partner_status) { :uninvited }
  let(:distributions) { [] }
  let(:requests) { [] }
  let(:users) { [] }

  before do
    allow(partner).to receive(:distributions).and_return(distributions)
    allow(partner).to receive(:requests).and_return(requests)
    allow(partner).to receive(:users).and_return(users)
  end

  it 'returns true when uninvited, no distributions, no requests, and no users' do
    expect(partner.deletable?).to be true
  end

  context 'when invited' do
    let(:partner_status) { :approved }

    it 'returns false even if no distributions, requests, or users' do
      expect(partner.deletable?).to be false
    end
  end

  context 'when there are distributions' do
    let(:distributions) { [build(:distribution)] }

    it 'returns false' do
      expect(partner.deletable?).to be false
    end
  end

  context 'when there are requests' do
    let(:requests) { [build(:request)] }

    it 'returns false' do
      expect(partner.deletable?).to be false
    end
  end

  context 'when there are users' do
    let(:users) { [build(:user)] }

    it 'returns false' do
      expect(partner.deletable?).to be false
    end
  end

  context 'when users is nil' do
    let(:users) { nil }

    it 'returns false' do
      expect(partner.deletable?).to be false
    end
  end
end
describe "#impact_metrics", :phoenix do
  let(:partner) { create(:partner) }
  let!(:family1) { create(:partners_family, partner: partner, guardian_zip_code: '12345') }
  let!(:family2) { create(:partners_family, partner: partner, guardian_zip_code: '67890') }
  let!(:child1) { create(:partners_child, family: family1) }
  let!(:child2) { create(:partners_child, family: family2) }

  it "returns the correct hash structure" do
    expect(partner.impact_metrics).to eq({
      families_served: 2,
      children_served: 2,
      family_zipcodes: 2,
      family_zipcodes_list: ['12345', '67890']
    })
  end

  it "returns correct families_served count" do
    expect(partner.impact_metrics[:families_served]).to eq(2)
  end

  it "returns correct children_served count" do
    expect(partner.impact_metrics[:children_served]).to eq(2)
  end

  it "returns correct family_zipcodes count" do
    expect(partner.impact_metrics[:family_zipcodes]).to eq(2)
  end

  it "returns correct family_zipcodes list" do
    expect(partner.impact_metrics[:family_zipcodes_list]).to match_array(['12345', '67890'])
  end

  describe "when counts are zero" do
    let(:partner) { create(:partner) }

    it "handles zero families_served count" do
      expect(partner.impact_metrics[:families_served]).to eq(0)
    end

    it "handles zero children_served count" do
      expect(partner.impact_metrics[:children_served]).to eq(0)
    end

    it "handles zero family_zipcodes count" do
      expect(partner.impact_metrics[:family_zipcodes]).to eq(0)
    end
  end

  describe "when lists are empty" do
    let(:partner) { create(:partner) }

    it "handles empty family_zipcodes list" do
      expect(partner.impact_metrics[:family_zipcodes_list]).to eq([])
    end
  end

  describe "error handling" do
    before do
      allow(partner).to receive(:families_served_count).and_raise(StandardError)
      allow(partner).to receive(:children_served_count).and_raise(StandardError)
      allow(partner).to receive(:family_zipcodes_count).and_raise(StandardError)
      allow(partner).to receive(:family_zipcodes_list).and_raise(StandardError)
    end

    it "handles errors in families_served_count" do
      expect { partner.impact_metrics[:families_served] }.to raise_error(StandardError)
    end

    it "handles errors in children_served_count" do
      expect { partner.impact_metrics[:children_served] }.to raise_error(StandardError)
    end

    it "handles errors in family_zipcodes_count" do
      expect { partner.impact_metrics[:family_zipcodes] }.to raise_error(StandardError)
    end

    it "handles errors in family_zipcodes_list" do
      expect { partner.impact_metrics[:family_zipcodes_list] }.to raise_error(StandardError)
    end
  end
end
describe "#quantity_year_to_date", :phoenix do
  let(:partner) { create(:partner) }
  let(:distribution_with_no_line_items) { create(:distribution, partner: partner, issued_at: Time.zone.today.beginning_of_year + 1.day) }
  let(:distribution_with_zero_quantity_line_items) do
    create(:distribution, :with_items, partner: partner, issued_at: Time.zone.today.beginning_of_year + 1.day, item_quantity: 0)
  end
  let(:distribution_with_line_items) do
    create(:distribution, :with_items, partner: partner, issued_at: Time.zone.today.beginning_of_year + 1.day, item_quantity: 5)
  end

  it "returns 0 when there are no distributions" do
    expect(partner.quantity_year_to_date).to eq(0)
  end

  it "returns 0 when distributions have no line items" do
    distribution_with_no_line_items
    expect(partner.quantity_year_to_date).to eq(0)
  end

  it "returns 0 when all line items have zero quantity" do
    distribution_with_zero_quantity_line_items
    expect(partner.quantity_year_to_date).to eq(0)
  end

  it "sums quantities of line items correctly" do
    distribution_with_line_items
    expect(partner.quantity_year_to_date).to eq(5)
  end

  describe "at the beginning of the year" do
    let(:distribution_on_first_day) { create(:distribution, :with_items, partner: partner, issued_at: Time.zone.today.beginning_of_year, item_quantity: 10) }

    it "includes distributions from the first day of the year" do
      distribution_on_first_day
      expect(partner.quantity_year_to_date).to eq(10)
    end
  end

  describe "during a leap year" do
    let(:leap_year_distribution) { create(:distribution, :with_items, partner: partner, issued_at: Date.new(2020, 2, 29), item_quantity: 20) }

    it "handles leap year correctly" do
      leap_year_distribution
      expect(partner.quantity_year_to_date).to eq(20)
    end
  end
end
describe '#quota_exceeded?', :phoenix do
  let(:partner_with_quota) { build(:partner, quota: 100) }
  let(:partner_without_quota) { build(:partner, quota: nil) }

  it 'returns true when total is greater than quota' do
    total = 150
    expect(partner_with_quota.quota_exceeded?(total)).to be true
  end

  it 'returns false when total is equal to quota' do
    total = 100
    expect(partner_with_quota.quota_exceeded?(total)).to be false
  end

  it 'returns false when total is less than quota' do
    total = 50
    expect(partner_with_quota.quota_exceeded?(total)).to be false
  end

  it 'returns false when quota is not present' do
    total = 150
    expect(partner_without_quota.quota_exceeded?(total)).to be false
  end
end
describe "#agency_info", :phoenix do
  let(:partner) { build(:partner) }
  let(:profile) { build(:partner_profile, partner: partner, agency_type: agency_type, address1: address1, address2: address2, city: city, state: state, zip_code: zip_code, website: website, other_agency_type: other_agency_type) }
  let(:agency_type) { nil }
  let(:address1) { "123 Main St" }
  let(:address2) { "Apt 4" }
  let(:city) { "Metropolis" }
  let(:state) { "NY" }
  let(:zip_code) { "12345" }
  let(:website) { "http://example.com" }
  let(:other_agency_type) { "Custom Agency" }

  before do
    allow(partner).to receive(:profile).and_return(profile)
  end

  it "returns cached @agency_info if already set" do
    partner.instance_variable_set(:@agency_info, { cached: true })
    expect(partner.agency_info).to eq({ cached: true })
  end

  context "when profile.agency_type is nil" do
    let(:agency_type) { nil }

    it "returns nil for agency_type" do
      expect(partner.agency_info[:agency_type]).to be_nil
    end
  end

  context "when profile.agency_type is :other" do
    let(:agency_type) { :other }

    it "includes other_agency_type in agency_type" do
      expect(partner.agency_info[:agency_type]).to eq("Other: Custom Agency")
    end
  end

  context "when profile.agency_type is not :other" do
    let(:agency_type) { :government }

    it "translates agency_type without other_agency_type" do
      expect(partner.agency_info[:agency_type]).to eq("Government")
    end
  end

  context "when profile.address1 and/or profile.address2 are present" do
    let(:address1) { "123 Main St" }
    let(:address2) { "Apt 4" }

    it "joins address1 and address2 correctly" do
      expect(partner.agency_info[:address]).to eq("123 Main St, Apt 4")
    end
  end

  context "when profile.address1 and profile.address2 are both absent" do
    let(:address1) { nil }
    let(:address2) { nil }

    it "returns empty string for address when both are absent" do
      expect(partner.agency_info[:address]).to eq("")
    end
  end

  it "returns correct city" do
    expect(partner.agency_info[:city]).to eq("Metropolis")
  end

  it "returns correct state" do
    expect(partner.agency_info[:state]).to eq("NY")
  end

  it "returns correct zip_code" do
    expect(partner.agency_info[:zip_code]).to eq("12345")
  end

  it "returns correct website" do
    expect(partner.agency_info[:website]).to eq("http://example.com")
  end
end
describe "#partials_to_show", :phoenix do
  let(:organization) { build(:organization) }
  let(:partner) { build(:partner, organization: organization) }
  let(:partner_form_fields) { nil }

  before do
    allow(organization).to receive(:partner_form_fields).and_return(partner_form_fields)
  end

  context "when partner_form_fields is present" do
    let(:partner_form_fields) { ["field1", "field2"] }

    it "returns the partner_form_fields" do
      expect(partner.partials_to_show).to eq(partner_form_fields)
    end
  end

  context "when partner_form_fields is not present" do
    it "returns ALL_PARTIALS" do
      expect(partner.partials_to_show).to eq(ALL_PARTIALS)
    end
  end
end
describe "#display_status", :phoenix do
  let(:partner_awaiting_review) { build(:partner, :awaiting_review) }
  let(:partner_uninvited) { build(:partner, :uninvited) }
  let(:partner_approved) { build(:partner, :approved) }
  let(:partner_other_status) { build(:partner, status: :some_other_status) }

  it "returns 'Submitted' when status is :awaiting_review" do
    expect(partner_awaiting_review.display_status).to eq('Submitted')
  end

  it "returns 'Pending' when status is :uninvited" do
    expect(partner_uninvited.display_status).to eq('Pending')
  end

  it "returns 'Verified' when status is :approved" do
    expect(partner_approved.display_status).to eq('Verified')
  end

  it "titleizes the status for any other status" do
    expect(partner_other_status.display_status).to eq('Some Other Status')
  end
end
describe '#approvable?', :phoenix do
  let(:partner_invited) { build(:partner, invited: true, awaiting_review: false) }
  let(:partner_awaiting_review) { build(:partner, invited: false, awaiting_review: true) }
  let(:partner_both_true) { build(:partner, invited: true, awaiting_review: true) }
  let(:partner_both_false) { build(:partner, invited: false, awaiting_review: false) }

  it 'returns true when invited? is true and awaiting_review? is false' do
    expect(partner_invited.approvable?).to be true
  end

  it 'returns true when invited? is false and awaiting_review? is true' do
    expect(partner_awaiting_review.approvable?).to be true
  end

  it 'returns true when both invited? and awaiting_review? are true' do
    expect(partner_both_true.approvable?).to be true
  end

  it 'returns false when both invited? and awaiting_review? are false' do
    expect(partner_both_false.approvable?).to be false
  end
end
describe "#import_csv", :phoenix do
  let(:organization) { create(:organization) }
  let(:valid_csv) { CSV.generate { |csv| csv << %w[name email]; csv << ["Partner Name", "partner@example.com"] } }
  let(:invalid_csv) { CSV.generate { |csv| csv << %w[name email]; csv << [nil, "partner@example.com"] } }
  let(:empty_csv) { CSV.generate { |csv| csv << [] } }

  it "imports CSV successfully" do
    errors = Partner.import_csv(valid_csv, organization.id)
    expect(errors).to be_empty
  end

  it "creates a partner with correct name" do
    Partner.import_csv(valid_csv, organization.id)
    expect(Partner.last.name).to eq("Partner Name")
  end

  describe "when partner creation fails" do
    before do
      allow_any_instance_of(PartnerCreateService).to receive(:call).and_wrap_original do |m, *args|
        partner = m.receiver.partner
        partner.errors.add(:base, "Creation error")
      end
    end

    it "returns error message" do
      errors = Partner.import_csv(valid_csv, organization.id)
      expect(errors).to include("Partner Name: Creation error")
    end
  end

  describe "with invalid CSV data" do
    it "returns error for missing name" do
      errors = Partner.import_csv(invalid_csv, organization.id)
      expect(errors).to include(": Name can't be blank")
    end
  end

  describe "with empty CSV" do
    it "returns no errors" do
      errors = Partner.import_csv(empty_csv, organization.id)
      expect(errors).to be_empty
    end
  end

  describe "when organization is not found" do
    it "raises ActiveRecord::RecordNotFound" do
      expect { Partner.import_csv(valid_csv, -1) }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
end
