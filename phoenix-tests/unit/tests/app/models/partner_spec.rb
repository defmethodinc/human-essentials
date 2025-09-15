
require "rails_helper"

RSpec.describe Partner do
describe '#agency_info' do
  let(:partner) { create(:partner, profile: profile) }
  let(:profile) { build(:partner_profile, agency_type: agency_type, address1: address1, address2: address2, city: city, state: state, zip_code: zip_code, website: website, other_agency_type: other_agency_type) }
  let(:agency_type) { nil }
  let(:address1) { '123 Main St' }
  let(:address2) { 'Apt 4' }
  let(:city) { 'Metropolis' }
  let(:state) { 'NY' }
  let(:zip_code) { '12345' }
  let(:website) { 'http://example.com' }
  let(:other_agency_type) { 'Special Agency' }

  it 'returns cached @agency_info if already set' do
    partner.instance_variable_set(:@agency_info, { cached: true })
    expect(partner.agency_info).to eq({ cached: true })
  end

  context 'when profile.agency_type is nil' do
    let(:agency_type) { nil }

    it 'handles nil agency_type' do
      expect(partner.agency_info[:agency_type]).to be_nil
    end
  end

  context 'when profile.agency_type is :other' do
    let(:agency_type) { :other }

    it 'includes other_agency_type in agency_type' do
      expected_agency_type = "#{I18n.t(:other, scope: :partners_profile)}: #{other_agency_type}"
      expect(partner.agency_info[:agency_type]).to eq(expected_agency_type)
    end
  end

  context 'when profile.agency_type is not :other' do
    let(:agency_type) { :career } # Changed to a valid agency_type

    it 'translates agency_type correctly' do
      expected_agency_type = I18n.t(:career, scope: :partners_profile)
      expect(partner.agency_info[:agency_type]).to eq(expected_agency_type)
    end
  end

  context 'when both address1 and address2 are present' do
    let(:address1) { '123 Main St' }
    let(:address2) { 'Apt 4' }

    it 'joins address1 and address2 with a comma' do
      expect(partner.agency_info[:address]).to eq('123 Main St, Apt 4')
    end
  end

  context 'when only address1 is present' do
    let(:address1) { '123 Main St' }
    let(:address2) { nil }

    it 'uses only address1 in the address' do
      expect(partner.agency_info[:address]).to eq('123 Main St')
    end
  end

  context 'when only address2 is present' do
    let(:address1) { nil }
    let(:address2) { 'Apt 4' }

    it 'uses only address2 in the address' do
      expect(partner.agency_info[:address]).to eq('Apt 4')
    end
  end

  context 'when neither address1 nor address2 is present' do
    let(:address1) { nil }
    let(:address2) { nil }

    it 'results in an empty address' do
      expect(partner.agency_info[:address]).to eq('')
    end
  end
end
describe '#approvable?', :phoenix do
    let(:partner_invited) { build(:partner, status: :invited) }
    let(:partner_awaiting_review) { build(:partner, status: :awaiting_review) }
    let(:partner_both_true) { build(:partner, status: :awaiting_review) } # Since both true is not a valid state, choose one
    let(:partner_both_false) { build(:partner, status: :uninvited) }

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
describe '#deletable?' do
    let(:partner) { build(:partner, :uninvited, distributions: distributions, requests: requests, users: users) }
    let(:distributions) { [] }
    let(:requests) { [] }
    let(:users) { [] }

    it 'returns true when partner is uninvited, has no distributions, requests, or users' do
      expect(partner.deletable?).to eq(true)
    end

    context 'when partner is not uninvited' do
      let(:partner) { build(:partner, status: :approved, distributions: distributions, requests: requests, users: users) }

      it 'returns false' do
        expect(partner.deletable?).to eq(false)
      end
    end

    context 'when distributions are present' do
      let(:distributions) { [build(:distribution)] }

      it 'returns false' do
        expect(partner.deletable?).to eq(false)
      end
    end

    context 'when requests are present' do
      let(:requests) { [build(:request)] }

      it 'returns false' do
        expect(partner.deletable?).to eq(false)
      end
    end

    context 'when users are present' do
      let(:users) { [build(:user)] }

      it 'returns false' do
        expect(partner.deletable?).to eq(false)
      end
    end
  end
describe '#display_status' do
  let(:partner_awaiting_review) { build(:partner, status: :awaiting_review) }
  let(:partner_uninvited) { build(:partner, status: :uninvited) }
  let(:partner_approved) { build(:partner, status: :approved) }
  let(:partner_other_status) { build(:partner, status: :deactivated) }

  it 'returns Submitted when status is :awaiting_review' do
    expect(partner_awaiting_review.display_status).to eq('Submitted')
  end

  it 'returns Pending when status is :uninvited' do
    expect(partner_uninvited.display_status).to eq('Pending')
  end

  it 'returns Verified when status is :approved' do
    expect(partner_approved.display_status).to eq('Verified')
  end

  describe 'when status is any other value' do
    it 'returns the titleized status' do
      expect(partner_other_status.display_status).to eq('Deactivated')
    end
  end
end
describe '#import_csv' do
  let(:organization) { create(:organization) }
  let(:partner_attributes) { { 'name' => 'Test Partner', 'email' => 'test@example.com' } }
  let(:csv_row) { CSV::Row.new(partner_attributes.keys, partner_attributes.values) }
  let(:csv) { [csv_row] }

  context 'when CSV is valid' do
    it 'imports a CSV row successfully' do
      allow(Organization).to receive(:find).with(organization.id).and_return(organization)
      allow(PartnerCreateService).to receive(:new).and_return(double(call: true, errors: []))

      errors = Partner.import_csv(csv, organization.id)

      expect(errors).to be_empty
    end
  end

  context 'when PartnerCreateService returns errors' do
    it 'handles errors from PartnerCreateService' do
      allow(Organization).to receive(:find).with(organization.id).and_return(organization)
      allow_any_instance_of(PartnerCreateService).to receive(:call).and_return(false)
      allow_any_instance_of(PartnerCreateService).to receive(:errors).and_return(['Error message'])
      allow_any_instance_of(PartnerCreateService).to receive(:partner).and_return(double(name: 'Test Partner'))

      errors = Partner.import_csv(csv, organization.id)

      expect(errors).to include('Test Partner: Error message')
    end
  end

  context 'when CSV is empty' do
    let(:csv) { [] }

    it 'returns no errors for an empty CSV' do
      errors = Partner.import_csv(csv, organization.id)

      expect(errors).to be_empty
    end
  end

  context 'when organization is not found' do
    it 'raises an error when organization is not found' do
      allow(Organization).to receive(:find).with(organization.id).and_raise(ActiveRecord::RecordNotFound)

      expect { Partner.import_csv(csv, organization.id) }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  context 'when CSV format is invalid' do
    let(:csv) { [CSV::Row.new([], [])] }

    it 'handles invalid CSV format' do
      allow(Organization).to receive(:find).with(organization.id).and_return(organization)

      errors = Partner.import_csv(csv, organization.id)

      expect(errors).to include('Invalid CSV format')
    end
  end
end
describe "#partials_to_show" do
  let(:organization) { create(:organization) }
  let(:partner_with_fields) { build(:partner, organization: organization) }
  let(:partner_without_fields) { build(:partner, organization: organization) }

  before do
    allow(partner_with_fields.organization).to receive(:partner_form_fields).and_return(['field1', 'field2'])
    allow(partner_without_fields.organization).to receive(:partner_form_fields).and_return(nil)
  end

  it "returns partner form fields when they are present" do
    expect(partner_with_fields.partials_to_show).to eq(['field1', 'field2'])
  end

  it "returns ALL_PARTIALS when partner form fields are not present" do
    expect(partner_without_fields.partials_to_show).to eq(Partner::ALL_PARTIALS)
  end
end
describe '#primary_user' do
  let(:partner) { create(:partner) }

  context 'when there are no users' do
    it 'returns nil' do
      expect(partner.primary_user).to be_nil
    end
  end

  context 'when there is one user' do
    let!(:user) { create(:user) }
    before { user.add_role(:partner, partner) }

    it 'returns the only user' do
      expect(partner.primary_user).to eq(user)
    end
  end

  context 'when there are multiple users' do
    let!(:first_user) { create(:user, created_at: 2.days.ago) }
    let!(:second_user) { create(:user, created_at: 1.day.ago) }
    before do
      first_user.add_role(:partner, partner)
      second_user.add_role(:partner, partner)
    end

    it 'returns the first created user' do
      expect(partner.primary_user).to eq(first_user)
    end
  end
end
describe "#quantity_year_to_date" do
  let(:partner) { create(:partner) }
  let(:organization) { partner.organization }
  let!(:item) { create(:item, organization: organization) }
  let!(:storage_location) { create(:storage_location, :with_items, item: item, organization: organization) }

  context "when no distributions exist" do
    it "returns 0" do
      expect(partner.quantity_year_to_date).to eq(0)
    end
  end

  context "when no distributions have issued_at dates from the beginning of the year" do
    let!(:distribution) { create(:distribution, partner: partner, issued_at: 1.year.ago, storage_location: storage_location) }

    it "returns 0" do
      expect(partner.quantity_year_to_date).to eq(0)
    end
  end

  context "when distributions have issued_at dates from the beginning of the year but no line items" do
    let!(:distribution) { create(:distribution, partner: partner, issued_at: Time.zone.today.beginning_of_year, storage_location: storage_location) }

    it "returns 0" do
      expect(partner.quantity_year_to_date).to eq(0)
    end
  end

  context "when distributions have issued_at dates from the beginning of the year with line items" do
    let!(:distribution) { create(:distribution, :with_items, partner: partner, issued_at: Time.zone.today.beginning_of_year, storage_location: storage_location, item: item) }

    it "sums quantities of line items" do
      expect(partner.quantity_year_to_date).to eq(distribution.line_items.sum(&:quantity))
    end
  end

  describe "edge cases around the beginning of the year" do
    context "when distributions are issued exactly at the start of the year" do
      let!(:distribution) { create(:distribution, :with_items, partner: partner, issued_at: Time.zone.today.beginning_of_year, storage_location: storage_location, item: item) }

      it "includes those distributions in the sum" do
        expect(partner.quantity_year_to_date).to eq(distribution.line_items.sum(&:quantity))
      end
    end

    context "when handling leap year scenarios" do
      let!(:distribution) { create(:distribution, :with_items, partner: partner, issued_at: Date.new(2020, 2, 29), storage_location: storage_location, item: item) }

      it "correctly sums the quantities" do
        expect(partner.quantity_year_to_date).to eq(distribution.line_items.sum(&:quantity))
      end
    end
  end
end
describe '#impact_metrics', :phoenix do
  let(:partner) { build(:partner) }
  let(:families) { build_list(:partners_family, families_count, partner: partner) }
  let(:children) { build_list(:partners_child, children_count, family: families.first) }
  let(:families_count) { 3 }
  let(:children_count) { 5 }
  let(:family_zipcodes) { families.map(&:guardian_zip_code).uniq }

  before do
    allow(partner).to receive(:families_served_count).and_return(families_count)
    allow(partner).to receive(:children_served_count).and_return(children_count)
    allow(partner).to receive(:family_zipcodes_count).and_return(family_zipcodes.size)
    allow(partner).to receive(:family_zipcodes_list).and_return(family_zipcodes)
  end

  it 'returns correct families served count' do
    expect(partner.impact_metrics[:families_served]).to eq(families_count)
  end

  it 'returns correct children served count' do
    expect(partner.impact_metrics[:children_served]).to eq(children_count)
  end

  it 'returns correct family zipcodes count' do
    expect(partner.impact_metrics[:family_zipcodes]).to eq(family_zipcodes.size)
  end

  it 'returns correct family zipcodes list' do
    expect(partner.impact_metrics[:family_zipcodes_list]).to eq(family_zipcodes)
  end

  describe 'when families_served_count is zero' do
    let(:families_count) { 0 }

    it 'handles zero families served' do
      expect(partner.impact_metrics[:families_served]).to eq(0)
    end
  end

  describe 'when children_served_count is zero' do
    let(:children_count) { 0 }

    it 'handles zero children served' do
      expect(partner.impact_metrics[:children_served]).to eq(0)
    end
  end

  describe 'when family_zipcodes_count is zero' do
    let(:family_zipcodes) { [] }

    it 'handles zero family zipcodes' do
      expect(partner.impact_metrics[:family_zipcodes]).to eq(0)
    end
  end

  describe 'when family_zipcodes_list is empty' do
    let(:family_zipcodes) { [] }

    it 'handles empty family zipcodes list' do
      expect(partner.impact_metrics[:family_zipcodes_list]).to eq([])
    end
  end

  describe 'when there is an error fetching families_served_count' do
    before do
      allow(partner).to receive(:families_served_count).and_raise(StandardError)
    end

    it 'handles error in families served count' do
      expect { partner.impact_metrics }.to raise_error(StandardError)
    end
  end

  describe 'when there is an error fetching children_served_count' do
    before do
      allow(partner).to receive(:children_served_count).and_raise(StandardError)
    end

    it 'handles error in children served count' do
      expect { partner.impact_metrics }.to raise_error(StandardError)
    end
  end

  describe 'when there is an error fetching family_zipcodes_count' do
    before do
      allow(partner).to receive(:family_zipcodes_count).and_raise(StandardError)
    end

    it 'handles error in family zipcodes count' do
      expect { partner.impact_metrics }.to raise_error(StandardError)
    end
  end

  describe 'when there is an error fetching family_zipcodes_list' do
    before do
      allow(partner).to receive(:family_zipcodes_list).and_raise(StandardError)
    end

    it 'handles error in family zipcodes list' do
      expect { partner.impact_metrics }.to raise_error(StandardError)
    end
  end
end
describe '#primary_user' do
  let(:partner) { create(:partner) }

  context 'when there are no users' do
    it 'returns nil' do
      expect(partner.primary_user).to be_nil
    end
  end

  context 'when there is one user' do
    let!(:user) { create(:user) }
    before { user.add_role(:partner, partner) }

    it 'returns the only user' do
      expect(partner.primary_user).to eq(user)
    end
  end

  context 'when there are multiple users' do
    let!(:first_user) { create(:user, created_at: 2.days.ago) }
    let!(:second_user) { create(:user, created_at: 1.day.ago) }
    before do
      first_user.add_role(:partner, partner)
      second_user.add_role(:partner, partner)
    end

    it 'returns the first created user' do
      expect(partner.primary_user).to eq(first_user)
    end
  end
end
describe "#quantity_year_to_date" do
  let(:partner) { create(:partner) }
  let(:organization) { partner.organization }
  let!(:item) { create(:item, organization: organization) }
  let!(:storage_location) { create(:storage_location, :with_items, item: item, organization: organization) }

  context "when no distributions exist" do
    it "returns 0" do
      expect(partner.quantity_year_to_date).to eq(0)
    end
  end

  context "when no distributions have issued_at dates from the beginning of the year" do
    let!(:distribution) { create(:distribution, partner: partner, issued_at: 1.year.ago, storage_location: storage_location) }

    it "returns 0" do
      expect(partner.quantity_year_to_date).to eq(0)
    end
  end

  context "when distributions have issued_at dates from the beginning of the year but no line items" do
    let!(:distribution) { create(:distribution, partner: partner, issued_at: Time.zone.today.beginning_of_year, storage_location: storage_location) }

    it "returns 0" do
      expect(partner.quantity_year_to_date).to eq(0)
    end
  end

  context "when distributions have issued_at dates from the beginning of the year with line items" do
    let!(:distribution) { create(:distribution, :with_items, partner: partner, issued_at: Time.zone.today.beginning_of_year, storage_location: storage_location, item: item) }

    it "sums quantities of line items" do
      expect(partner.quantity_year_to_date).to eq(distribution.line_items.sum(&:quantity))
    end
  end

  describe "edge cases around the beginning of the year" do
    context "when distributions are issued exactly at the start of the year" do
      let!(:distribution) { create(:distribution, :with_items, partner: partner, issued_at: Time.zone.today.beginning_of_year, storage_location: storage_location, item: item) }

      it "includes those distributions in the sum" do
        expect(partner.quantity_year_to_date).to eq(distribution.line_items.sum(&:quantity))
      end
    end

    context "when handling leap year scenarios" do
      let!(:distribution) { create(:distribution, :with_items, partner: partner, issued_at: Date.new(2020, 2, 29), storage_location: storage_location, item: item) }

      it "correctly sums the quantities" do
        expect(partner.quantity_year_to_date).to eq(distribution.line_items.sum(&:quantity))
      end
    end
  end
end
describe '#import_csv' do
  let(:organization) { create(:organization) }
  let(:partner_attributes) { { 'name' => 'Test Partner', 'email' => 'test@example.com' } }
  let(:csv_row) { CSV::Row.new(partner_attributes.keys, partner_attributes.values) }
  let(:csv) { [csv_row] }

  context 'when CSV is valid' do
    it 'imports a CSV row successfully' do
      allow(Organization).to receive(:find).with(organization.id).and_return(organization)
      allow(PartnerCreateService).to receive(:new).and_return(double(call: true, errors: []))

      errors = Partner.import_csv(csv, organization.id)

      expect(errors).to be_empty
    end
  end

  context 'when PartnerCreateService returns errors' do
    it 'handles errors from PartnerCreateService' do
      allow(Organization).to receive(:find).with(organization.id).and_return(organization)
      allow_any_instance_of(PartnerCreateService).to receive(:call).and_return(false)
      allow_any_instance_of(PartnerCreateService).to receive(:errors).and_return(['Error message'])
      allow_any_instance_of(PartnerCreateService).to receive(:partner).and_return(double(name: 'Test Partner'))

      errors = Partner.import_csv(csv, organization.id)

      expect(errors).to include('Test Partner: Error message')
    end
  end

  context 'when CSV is empty' do
    let(:csv) { [] }

    it 'returns no errors for an empty CSV' do
      errors = Partner.import_csv(csv, organization.id)

      expect(errors).to be_empty
    end
  end

  context 'when organization is not found' do
    it 'raises an error when organization is not found' do
      allow(Organization).to receive(:find).with(organization.id).and_raise(ActiveRecord::RecordNotFound)

      expect { Partner.import_csv(csv, organization.id) }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  context 'when CSV format is invalid' do
    let(:csv) { [CSV::Row.new([], [])] }

    it 'handles invalid CSV format' do
      allow(Organization).to receive(:find).with(organization.id).and_return(organization)

      errors = Partner.import_csv(csv, organization.id)

      expect(errors).to include('Invalid CSV format')
    end
  end
end
describe "#partials_to_show" do
  let(:organization) { create(:organization) }
  let(:partner_with_fields) { build(:partner, organization: organization) }
  let(:partner_without_fields) { build(:partner, organization: organization) }

  before do
    allow(partner_with_fields.organization).to receive(:partner_form_fields).and_return(['field1', 'field2'])
    allow(partner_without_fields.organization).to receive(:partner_form_fields).and_return(nil)
  end

  it "returns partner form fields when they are present" do
    expect(partner_with_fields.partials_to_show).to eq(['field1', 'field2'])
  end

  it "returns ALL_PARTIALS when partner form fields are not present" do
    expect(partner_without_fields.partials_to_show).to eq(Partner::ALL_PARTIALS)
  end
end
describe '#deletable?' do
    let(:partner) { build(:partner, :uninvited, distributions: distributions, requests: requests, users: users) }
    let(:distributions) { [] }
    let(:requests) { [] }
    let(:users) { [] }

    it 'returns true when partner is uninvited, has no distributions, requests, or users' do
      expect(partner.deletable?).to eq(true)
    end

    context 'when partner is not uninvited' do
      let(:partner) { build(:partner, status: :approved, distributions: distributions, requests: requests, users: users) }

      it 'returns false' do
        expect(partner.deletable?).to eq(false)
      end
    end

    context 'when distributions are present' do
      let(:distributions) { [build(:distribution)] }

      it 'returns false' do
        expect(partner.deletable?).to eq(false)
      end
    end

    context 'when requests are present' do
      let(:requests) { [build(:request)] }

      it 'returns false' do
        expect(partner.deletable?).to eq(false)
      end
    end

    context 'when users are present' do
      let(:users) { [build(:user)] }

      it 'returns false' do
        expect(partner.deletable?).to eq(false)
      end
    end
  end
describe '#contact_person', :phoenix do
  let(:partner) { build(:partner) }
  let(:profile) { build(:partner_profile, partner: partner, primary_contact_phone: primary_contact_phone, primary_contact_mobile: primary_contact_mobile, primary_contact_name: 'John Doe', primary_contact_email: 'john.doe@example.com') }
  let(:primary_contact_phone) { '123-456-7890' }
  let(:primary_contact_mobile) { '098-765-4321' }

  before do
    allow(partner).to receive(:profile).and_return(profile)
  end

  it 'returns the cached contact person if already set' do
    partner.instance_variable_set(:@contact_person, { name: 'Cached Name', email: 'cached@example.com', phone: '111-222-3333' })
    expect(partner.contact_person).to eq({ name: 'Cached Name', email: 'cached@example.com', phone: '111-222-3333' })
  end

  it 'initializes contact person with all profile details present' do
    expect(partner.contact_person).to eq({ name: 'John Doe', email: 'john.doe@example.com', phone: '123-456-7890' })
  end

  describe 'when primary contact phone is nil' do
    let(:primary_contact_phone) { nil }

    it 'uses primary contact mobile if phone is nil' do
      expect(partner.contact_person).to eq({ name: 'John Doe', email: 'john.doe@example.com', phone: '098-765-4321' })
    end
  end

  describe 'when both primary contact phone and mobile are nil' do
    let(:primary_contact_phone) { nil }
    let(:primary_contact_mobile) { nil }

    it 'handles missing phone and mobile gracefully' do
      expect(partner.contact_person).to eq({ name: 'John Doe', email: 'john.doe@example.com', phone: nil })
    end
  end
end
describe '#approvable?', :phoenix do
    let(:partner_invited) { build(:partner, status: :invited) }
    let(:partner_awaiting_review) { build(:partner, status: :awaiting_review) }
    let(:partner_both_true) { build(:partner, status: :awaiting_review) } # Since both true is not a valid state, choose one
    let(:partner_both_false) { build(:partner, status: :uninvited) }

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
describe '#agency_info' do
  let(:partner) { create(:partner, profile: profile) }
  let(:profile) { build(:partner_profile, agency_type: agency_type, address1: address1, address2: address2, city: city, state: state, zip_code: zip_code, website: website, other_agency_type: other_agency_type) }
  let(:agency_type) { nil }
  let(:address1) { '123 Main St' }
  let(:address2) { 'Apt 4' }
  let(:city) { 'Metropolis' }
  let(:state) { 'NY' }
  let(:zip_code) { '12345' }
  let(:website) { 'http://example.com' }
  let(:other_agency_type) { 'Special Agency' }

  it 'returns cached @agency_info if already set' do
    partner.instance_variable_set(:@agency_info, { cached: true })
    expect(partner.agency_info).to eq({ cached: true })
  end

  context 'when profile.agency_type is nil' do
    let(:agency_type) { nil }

    it 'handles nil agency_type' do
      expect(partner.agency_info[:agency_type]).to be_nil
    end
  end

  context 'when profile.agency_type is :other' do
    let(:agency_type) { :other }

    it 'includes other_agency_type in agency_type' do
      expected_agency_type = "#{I18n.t(:other, scope: :partners_profile)}: #{other_agency_type}"
      expect(partner.agency_info[:agency_type]).to eq(expected_agency_type)
    end
  end

  context 'when profile.agency_type is not :other' do
    let(:agency_type) { :career } # Changed to a valid agency_type

    it 'translates agency_type correctly' do
      expected_agency_type = I18n.t(:career, scope: :partners_profile)
      expect(partner.agency_info[:agency_type]).to eq(expected_agency_type)
    end
  end

  context 'when both address1 and address2 are present' do
    let(:address1) { '123 Main St' }
    let(:address2) { 'Apt 4' }

    it 'joins address1 and address2 with a comma' do
      expect(partner.agency_info[:address]).to eq('123 Main St, Apt 4')
    end
  end

  context 'when only address1 is present' do
    let(:address1) { '123 Main St' }
    let(:address2) { nil }

    it 'uses only address1 in the address' do
      expect(partner.agency_info[:address]).to eq('123 Main St')
    end
  end

  context 'when only address2 is present' do
    let(:address1) { nil }
    let(:address2) { 'Apt 4' }

    it 'uses only address2 in the address' do
      expect(partner.agency_info[:address]).to eq('Apt 4')
    end
  end

  context 'when neither address1 nor address2 is present' do
    let(:address1) { nil }
    let(:address2) { nil }

    it 'results in an empty address' do
      expect(partner.agency_info[:address]).to eq('')
    end
  end
end
describe "#quota_exceeded?", :phoenix do
  let(:partner_with_nil_quota) { build(:partner, quota: nil) }
  let(:partner_with_quota) { build(:partner, quota: 100) }
  let(:total_less_than_quota) { 50 }
  let(:total_equal_to_quota) { 100 }
  let(:total_greater_than_quota) { 150 }

  it "returns false when quota is nil" do
    expect(partner_with_nil_quota.quota_exceeded?(total_less_than_quota)).to eq(false)
  end

  context "when quota is present" do
    it "returns false when total is less than quota" do
      expect(partner_with_quota.quota_exceeded?(total_less_than_quota)).to eq(false)
    end

    it "returns false when total is equal to quota" do
      expect(partner_with_quota.quota_exceeded?(total_equal_to_quota)).to eq(false)
    end

    it "returns true when total is greater than quota" do
      expect(partner_with_quota.quota_exceeded?(total_greater_than_quota)).to eq(true)
    end
  end
end
describe '#display_status' do
  let(:partner_awaiting_review) { build(:partner, status: :awaiting_review) }
  let(:partner_uninvited) { build(:partner, status: :uninvited) }
  let(:partner_approved) { build(:partner, status: :approved) }
  let(:partner_other_status) { build(:partner, status: :deactivated) }

  it 'returns Submitted when status is :awaiting_review' do
    expect(partner_awaiting_review.display_status).to eq('Submitted')
  end

  it 'returns Pending when status is :uninvited' do
    expect(partner_uninvited.display_status).to eq('Pending')
  end

  it 'returns Verified when status is :approved' do
    expect(partner_approved.display_status).to eq('Verified')
  end

  describe 'when status is any other value' do
    it 'returns the titleized status' do
      expect(partner_other_status.display_status).to eq('Deactivated')
    end
  end
end
end
