
require "rails_helper"

RSpec.describe Partner do
describe '#agency_info' do
  let(:partner) { build(:partner) }
  let(:profile) { build(:partner_profile, partner: partner, address1: address1, address2: address2, city: city, state: state, zip_code: zip_code, website: website, agency_type: agency_type, other_agency_type: other_agency_type) }
  let(:address1) { '123 Main St' }
  let(:address2) { 'Apt 4' }
  let(:city) { 'Metropolis' }
  let(:state) { 'NY' }
  let(:zip_code) { '12345' }
  let(:website) { 'http://example.com' }
  let(:agency_type) { 'career' }  # Changed to a valid agency_type
  let(:other_agency_type) { 'Custom Agency' }

  before do
    allow(partner).to receive(:profile).and_return(profile)
  end

  it 'returns memoized @agency_info if already set' do
    partner.instance_variable_set(:@agency_info, { memoized: true })
    expect(partner.agency_info).to eq({ memoized: true })
  end

  describe 'when profile attributes are present' do
    it 'combines address1 and address2 correctly' do
      expected_address = '123 Main St, Apt 4'
      expect(partner.agency_info[:address]).to eq(expected_address)
    end

    it 'returns correct city' do
      expect(partner.agency_info[:city]).to eq('Metropolis')
    end

    it 'returns correct state' do
      expect(partner.agency_info[:state]).to eq('NY')
    end

    it 'returns correct zip_code' do
      expect(partner.agency_info[:zip_code]).to eq('12345')
    end

    it 'returns correct website' do
      expect(partner.agency_info[:website]).to eq('http://example.com')
    end
  end

  describe 'when profile.agency_type is :other' do
    let(:agency_type) { 'other' }

    it 'appends other_agency_type to the translated string' do
      translated_type = I18n.t(:other, scope: :partners_profile)
      expected_agency_type = "#{translated_type}: Custom Agency"
      expect(partner.agency_info[:agency_type]).to eq(expected_agency_type)
    end
  end

  describe 'when profile.agency_type is not :other' do
    it 'translates the agency type correctly' do
      translated_type = I18n.t(:career, scope: :partners_profile)
      expect(partner.agency_info[:agency_type]).to eq(translated_type)
    end
  end
end
describe '#contact_person' do
  let(:partner_with_contact_details) do
    create(:partner) do |partner|
      partner.profile.primary_contact_name = 'John Doe'
      partner.profile.primary_contact_email = 'john.doe@example.com'
      partner.profile.primary_contact_phone = '123-456-7890'
      partner.profile.primary_contact_mobile = '098-765-4321'
    end
  end

  let(:partner_with_mobile_only) do
    create(:partner) do |partner|
      partner.profile.primary_contact_name = 'Jane Doe'
      partner.profile.primary_contact_email = 'jane.doe@example.com'
      partner.profile.primary_contact_phone = nil
      partner.profile.primary_contact_mobile = '098-765-4321'
    end
  end

  let(:partner_with_no_contact_details) do
    create(:partner) do |partner|
      partner.profile.primary_contact_name = nil
      partner.profile.primary_contact_email = nil
      partner.profile.primary_contact_phone = nil
      partner.profile.primary_contact_mobile = nil
    end
  end

  it 'returns the existing @contact_person if already set' do
    partner = partner_with_contact_details
    existing_contact_person = { name: 'Existing Name', email: 'existing@example.com', phone: '111-222-3333' }
    partner.instance_variable_set(:@contact_person, existing_contact_person)
    expect(partner.contact_person).to eq(existing_contact_person)
  end

  describe 'when profile has primary contact details' do
    it 'sets @contact_person with name, email, and phone' do
      partner = partner_with_contact_details
      expected_contact_person = {
        name: 'John Doe',
        email: 'john.doe@example.com',
        phone: '123-456-7890'
      }
      expect(partner.contact_person).to eq(expected_contact_person)
    end
  end

  describe 'when profile has primary contact details but no phone' do
    it 'sets @contact_person with name, email, and mobile' do
      partner = partner_with_mobile_only
      expected_contact_person = {
        name: 'Jane Doe',
        email: 'jane.doe@example.com',
        phone: '098-765-4321'
      }
      expect(partner.contact_person).to eq(expected_contact_person)
    end
  end

  describe 'when profile has no primary contact details' do
    it 'sets @contact_person with nil values' do
      partner = partner_with_no_contact_details
      expected_contact_person = {
        name: nil,
        email: nil,
        phone: nil
      }
      expect(partner.contact_person).to eq(expected_contact_person)
    end
  end
end
describe "#deletable?" do
  let(:partner) { build(:partner, :uninvited) }
  let(:invited_partner) { build(:partner, status: :invited) }
  let(:partner_with_distributions) { build(:partner, :uninvited, distributions: [build(:distribution)]) }
  let(:partner_with_requests) { build(:partner, :uninvited, requests: [build(:request)]) }
  let(:partner_with_users) do
    partner = build(:partner, :uninvited)
    user = build(:partner_user)
    user.roles << build(:role, resource: partner)
    partner.users << user
    partner
  end

  it "returns true when uninvited, no distributions, no requests, and no users" do
    expect(partner.deletable?).to be true
  end

  it "returns false when invited" do
    expect(invited_partner.deletable?).to be false
  end

  it "returns false when there are distributions" do
    expect(partner_with_distributions.deletable?).to be false
  end

  it "returns false when there are requests" do
    expect(partner_with_requests.deletable?).to be false
  end

  it "returns false when there are users" do
    expect(partner_with_users.deletable?).to be false
  end
end
describe '#display_status' do
  let(:partner_awaiting_review) { build(:partner, status: :awaiting_review) }
  let(:partner_uninvited) { build(:partner, status: :uninvited) }
  let(:partner_approved) { build(:partner, status: :approved) }
  let(:partner_deactivated) { build(:partner, status: :deactivated) } # Use a valid status

  it 'returns Submitted when status is :awaiting_review' do
    expect(partner_awaiting_review.display_status).to eq('Submitted'.encode('UTF-8'))
  end

  it 'returns Pending when status is :uninvited' do
    expect(partner_uninvited.display_status).to eq('Pending'.encode('UTF-8'))
  end

  it 'returns Verified when status is :approved' do
    expect(partner_approved.display_status).to eq('Verified'.encode('UTF-8'))
  end

  it 'titleizes the status for any other status' do
    expect(partner_deactivated.display_status).to eq('Deactivated'.encode('UTF-8'))
  end
end
describe '#import_csv' do
    let(:organization) { create(:organization) }
    let(:valid_csv_row) { { 'name' => 'Valid Partner', 'email' => 'valid@example.com' } }
    let(:invalid_csv_row) { { 'name' => '', 'email' => 'invalid@example.com' } }
    let(:csv_with_mixed_results) { [valid_csv_row, invalid_csv_row] }
    let(:empty_csv) { [] }
    let(:invalid_organization_id) { -1 }

    let(:service_double) { double("PartnerCreateService", call: service_call_double) }
    let(:service_call_double) { double("ServiceCall", errors: ActiveModel::Errors.new(Partner.new)) }

    before do
      allow(PartnerCreateService).to receive(:new).and_return(service_double)
      allow(service_double).to receive(:errors).and_return(ActiveModel::Errors.new(Partner.new))
    end

    it 'imports a CSV row successfully' do
      allow(service_call_double.errors).to receive(:empty?).and_return(true)
      errors = Partner.import_csv([valid_csv_row], organization.id)
      expect(errors).to be_empty
    end

    it 'collects errors for a CSV row that cannot be imported' do
      allow(service_call_double.errors).to receive(:present?).and_return(true)
      allow(service_call_double.errors).to receive(:full_messages).and_return(["Name can't be blank"])
      errors = Partner.import_csv([invalid_csv_row], organization.id)
      expect(errors).to include("Invalid Partner: Name can't be blank")
    end

    it 'handles an empty CSV' do
      errors = Partner.import_csv(empty_csv, organization.id)
      expect(errors).to be_empty
    end

    it 'raises an error for an invalid organization ID' do
      expect { Partner.import_csv([valid_csv_row], invalid_organization_id) }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it 'handles a CSV with mixed results' do
      allow(service_call_double.errors).to receive(:empty?).and_return(false, true)
      allow(service_call_double.errors).to receive(:full_messages).and_return(["Name can't be blank"])
      errors = Partner.import_csv(csv_with_mixed_results, organization.id)
      expect(errors).to include("Invalid Partner: Name can't be blank")
    end
  end
describe "#partials_to_show" do
  let(:organization_with_fields) { build(:organization, partner_form_fields: ['field1', 'field2']) }
  let(:organization_without_fields) { build(:organization, partner_form_fields: []) }

  context "when partner form fields are present" do
    before do
      allow(subject).to receive(:organization).and_return(organization_with_fields)
    end

    it "returns the partner form fields" do
      expect(subject.partials_to_show).to eq(['field1', 'field2'])
    end
  end

  context "when partner form fields are not present" do
    before do
      allow(subject).to receive(:organization).and_return(organization_without_fields)
    end

    it "returns ALL_PARTIALS" do
      expect(subject.partials_to_show).to eq(Partner::ALL_PARTIALS)
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

    context 'when there is only one user' do
      let!(:user) { create(:user, partner: partner) }

      it 'returns the user' do
        expect(partner.primary_user).to eq(user)
      end
    end

    context 'when there are multiple users' do
      let!(:user1) { create(:user, partner: partner, created_at: 2.days.ago) }
      let!(:user2) { create(:user, partner: partner, created_at: 1.day.ago) }

      it 'returns the earliest created user' do
        expect(partner.primary_user).to eq(user1)
      end
    end

    context 'when multiple users have the same creation date' do
      let!(:user1) { create(:user, partner: partner, created_at: 1.day.ago) }
      let!(:user2) { create(:user, partner: partner, created_at: 1.day.ago) }

      it 'returns one user' do
        expect([user1, user2]).to include(partner.primary_user)
      end
    end
  end
describe '#quantity_year_to_date' do
  let(:partner) { create(:partner) }
  let(:organization) { create(:organization) }
  let(:storage_location) { create(:storage_location, organization: organization) }
  let(:item) { create(:item, organization: organization) }

  before do
    storage_location.items << item
  end

  context 'when there are no distributions for the current year' do
    it 'returns 0' do
      expect(partner.quantity_year_to_date).to eq(0)
    end
  end

  context 'when distributions have no line items' do
    let!(:distribution) { create(:distribution, partner: partner, organization: organization, issued_at: Time.zone.today.beginning_of_year, storage_location: storage_location) }

    it 'returns 0' do
      expect(partner.quantity_year_to_date).to eq(0)
    end
  end

  context 'when calculating the total quantity for distributions with line items' do
    let!(:distribution) { create(:distribution, :with_items, partner: partner, organization: organization, issued_at: Time.zone.today.beginning_of_year, storage_location: storage_location, item_quantity: 10, item: item) }

    it 'calculates the total quantity' do
      expect(partner.quantity_year_to_date).to eq(10)
    end
  end

  context 'when calculating the total quantity for multiple distributions with line items' do
    let!(:distribution1) { create(:distribution, :with_items, partner: partner, organization: organization, issued_at: Time.zone.today.beginning_of_year, storage_location: storage_location, item_quantity: 10, item: item) }
    let!(:distribution2) { create(:distribution, :with_items, partner: partner, organization: organization, issued_at: Time.zone.today.beginning_of_year, storage_location: storage_location, item_quantity: 20, item: item) }

    it 'calculates the total quantity' do
      expect(partner.quantity_year_to_date).to eq(30)
    end
  end

  context 'when including distributions issued exactly at the beginning of the year' do
    let!(:distribution) { create(:distribution, :with_items, partner: partner, organization: organization, issued_at: Time.zone.today.beginning_of_year, storage_location: storage_location, item_quantity: 15, item: item) }

    it 'includes the distribution' do
      expect(partner.quantity_year_to_date).to eq(15)
    end
  end

  context 'when including distributions issued on the current date' do
    let!(:distribution) { create(:distribution, :with_items, partner: partner, organization: organization, issued_at: Time.zone.today, storage_location: storage_location, item_quantity: 25, item: item) }

    it 'includes the distribution' do
      expect(partner.quantity_year_to_date).to eq(25)
    end
  end
end
describe '#import_csv' do
    let(:organization) { create(:organization) }
    let(:valid_csv_row) { { 'name' => 'Valid Partner', 'email' => 'valid@example.com' } }
    let(:invalid_csv_row) { { 'name' => '', 'email' => 'invalid@example.com' } }
    let(:csv_with_mixed_results) { [valid_csv_row, invalid_csv_row] }
    let(:empty_csv) { [] }
    let(:invalid_organization_id) { -1 }

    let(:service_double) { double("PartnerCreateService", call: service_call_double) }
    let(:service_call_double) { double("ServiceCall", errors: ActiveModel::Errors.new(Partner.new)) }

    before do
      allow(PartnerCreateService).to receive(:new).and_return(service_double)
      allow(service_double).to receive(:errors).and_return(ActiveModel::Errors.new(Partner.new))
    end

    it 'imports a CSV row successfully' do
      allow(service_call_double.errors).to receive(:empty?).and_return(true)
      errors = Partner.import_csv([valid_csv_row], organization.id)
      expect(errors).to be_empty
    end

    it 'collects errors for a CSV row that cannot be imported' do
      allow(service_call_double.errors).to receive(:present?).and_return(true)
      allow(service_call_double.errors).to receive(:full_messages).and_return(["Name can't be blank"])
      errors = Partner.import_csv([invalid_csv_row], organization.id)
      expect(errors).to include("Invalid Partner: Name can't be blank")
    end

    it 'handles an empty CSV' do
      errors = Partner.import_csv(empty_csv, organization.id)
      expect(errors).to be_empty
    end

    it 'raises an error for an invalid organization ID' do
      expect { Partner.import_csv([valid_csv_row], invalid_organization_id) }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it 'handles a CSV with mixed results' do
      allow(service_call_double.errors).to receive(:empty?).and_return(false, true)
      allow(service_call_double.errors).to receive(:full_messages).and_return(["Name can't be blank"])
      errors = Partner.import_csv(csv_with_mixed_results, organization.id)
      expect(errors).to include("Invalid Partner: Name can't be blank")
    end
  end
describe '#quantity_year_to_date' do
  let(:partner) { create(:partner) }
  let(:organization) { create(:organization) }
  let(:storage_location) { create(:storage_location, organization: organization) }
  let(:item) { create(:item, organization: organization) }

  before do
    storage_location.items << item
  end

  context 'when there are no distributions for the current year' do
    it 'returns 0' do
      expect(partner.quantity_year_to_date).to eq(0)
    end
  end

  context 'when distributions have no line items' do
    let!(:distribution) { create(:distribution, partner: partner, organization: organization, issued_at: Time.zone.today.beginning_of_year, storage_location: storage_location) }

    it 'returns 0' do
      expect(partner.quantity_year_to_date).to eq(0)
    end
  end

  context 'when calculating the total quantity for distributions with line items' do
    let!(:distribution) { create(:distribution, :with_items, partner: partner, organization: organization, issued_at: Time.zone.today.beginning_of_year, storage_location: storage_location, item_quantity: 10, item: item) }

    it 'calculates the total quantity' do
      expect(partner.quantity_year_to_date).to eq(10)
    end
  end

  context 'when calculating the total quantity for multiple distributions with line items' do
    let!(:distribution1) { create(:distribution, :with_items, partner: partner, organization: organization, issued_at: Time.zone.today.beginning_of_year, storage_location: storage_location, item_quantity: 10, item: item) }
    let!(:distribution2) { create(:distribution, :with_items, partner: partner, organization: organization, issued_at: Time.zone.today.beginning_of_year, storage_location: storage_location, item_quantity: 20, item: item) }

    it 'calculates the total quantity' do
      expect(partner.quantity_year_to_date).to eq(30)
    end
  end

  context 'when including distributions issued exactly at the beginning of the year' do
    let!(:distribution) { create(:distribution, :with_items, partner: partner, organization: organization, issued_at: Time.zone.today.beginning_of_year, storage_location: storage_location, item_quantity: 15, item: item) }

    it 'includes the distribution' do
      expect(partner.quantity_year_to_date).to eq(15)
    end
  end

  context 'when including distributions issued on the current date' do
    let!(:distribution) { create(:distribution, :with_items, partner: partner, organization: organization, issued_at: Time.zone.today, storage_location: storage_location, item_quantity: 25, item: item) }

    it 'includes the distribution' do
      expect(partner.quantity_year_to_date).to eq(25)
    end
  end
end
describe '#impact_metrics', :phoenix do
  let(:partner) { create(:partner) }
  let(:families) { build_list(:partners_family, 3, partner: partner) }
  let(:children) { build_list(:partners_child, 5, family: families.first) }
  let(:zipcodes) { families.map(&:guardian_zip_code).uniq }

  before do
    allow(partner).to receive(:families_served_count).and_return(families.size)
    allow(partner).to receive(:children_served_count).and_return(children.size)
    allow(partner).to receive(:family_zipcodes_count).and_return(zipcodes.size)
    allow(partner).to receive(:family_zipcodes_list).and_return(zipcodes)
  end

  it 'returns a hash with correct keys' do
    expect(partner.impact_metrics.keys).to contain_exactly(:families_served, :children_served, :family_zipcodes, :family_zipcodes_list)
  end

  it 'returns correct families_served count' do
    expect(partner.impact_metrics[:families_served]).to eq(families.size)
  end

  it 'returns correct children_served count' do
    expect(partner.impact_metrics[:children_served]).to eq(children.size)
  end

  it 'returns correct family_zipcodes count' do
    expect(partner.impact_metrics[:family_zipcodes]).to eq(zipcodes.size)
  end

  it 'returns correct family_zipcodes list' do
    expect(partner.impact_metrics[:family_zipcodes_list]).to match_array(zipcodes)
  end

  describe 'when families_served_count is nil' do
    before do
      allow(partner).to receive(:families_served_count).and_return(nil)
    end

    it 'handles nil families_served_count gracefully' do
      expect(partner.impact_metrics[:families_served]).to be_nil
    end
  end

  describe 'when children_served_count is nil' do
    before do
      allow(partner).to receive(:children_served_count).and_return(nil)
    end

    it 'handles nil children_served_count gracefully' do
      expect(partner.impact_metrics[:children_served]).to be_nil
    end
  end

  describe 'when family_zipcodes_count is nil' do
    before do
      allow(partner).to receive(:family_zipcodes_count).and_return(nil)
    end

    it 'handles nil family_zipcodes_count gracefully' do
      expect(partner.impact_metrics[:family_zipcodes]).to be_nil
    end
  end

  describe 'when family_zipcodes_list is nil' do
    before do
      allow(partner).to receive(:family_zipcodes_list).and_return(nil)
    end

    it 'handles nil family_zipcodes_list gracefully' do
      expect(partner.impact_metrics[:family_zipcodes_list]).to be_nil
    end
  end
end
describe '#contact_person' do
  let(:partner_with_contact_details) do
    create(:partner) do |partner|
      partner.profile.primary_contact_name = 'John Doe'
      partner.profile.primary_contact_email = 'john.doe@example.com'
      partner.profile.primary_contact_phone = '123-456-7890'
      partner.profile.primary_contact_mobile = '098-765-4321'
    end
  end

  let(:partner_with_mobile_only) do
    create(:partner) do |partner|
      partner.profile.primary_contact_name = 'Jane Doe'
      partner.profile.primary_contact_email = 'jane.doe@example.com'
      partner.profile.primary_contact_phone = nil
      partner.profile.primary_contact_mobile = '098-765-4321'
    end
  end

  let(:partner_with_no_contact_details) do
    create(:partner) do |partner|
      partner.profile.primary_contact_name = nil
      partner.profile.primary_contact_email = nil
      partner.profile.primary_contact_phone = nil
      partner.profile.primary_contact_mobile = nil
    end
  end

  it 'returns the existing @contact_person if already set' do
    partner = partner_with_contact_details
    existing_contact_person = { name: 'Existing Name', email: 'existing@example.com', phone: '111-222-3333' }
    partner.instance_variable_set(:@contact_person, existing_contact_person)
    expect(partner.contact_person).to eq(existing_contact_person)
  end

  describe 'when profile has primary contact details' do
    it 'sets @contact_person with name, email, and phone' do
      partner = partner_with_contact_details
      expected_contact_person = {
        name: 'John Doe',
        email: 'john.doe@example.com',
        phone: '123-456-7890'
      }
      expect(partner.contact_person).to eq(expected_contact_person)
    end
  end

  describe 'when profile has primary contact details but no phone' do
    it 'sets @contact_person with name, email, and mobile' do
      partner = partner_with_mobile_only
      expected_contact_person = {
        name: 'Jane Doe',
        email: 'jane.doe@example.com',
        phone: '098-765-4321'
      }
      expect(partner.contact_person).to eq(expected_contact_person)
    end
  end

  describe 'when profile has no primary contact details' do
    it 'sets @contact_person with nil values' do
      partner = partner_with_no_contact_details
      expected_contact_person = {
        name: nil,
        email: nil,
        phone: nil
      }
      expect(partner.contact_person).to eq(expected_contact_person)
    end
  end
end
describe '#agency_info' do
  let(:partner) { build(:partner) }
  let(:profile) { build(:partner_profile, partner: partner, address1: address1, address2: address2, city: city, state: state, zip_code: zip_code, website: website, agency_type: agency_type, other_agency_type: other_agency_type) }
  let(:address1) { '123 Main St' }
  let(:address2) { 'Apt 4' }
  let(:city) { 'Metropolis' }
  let(:state) { 'NY' }
  let(:zip_code) { '12345' }
  let(:website) { 'http://example.com' }
  let(:agency_type) { 'career' }  # Changed to a valid agency_type
  let(:other_agency_type) { 'Custom Agency' }

  before do
    allow(partner).to receive(:profile).and_return(profile)
  end

  it 'returns memoized @agency_info if already set' do
    partner.instance_variable_set(:@agency_info, { memoized: true })
    expect(partner.agency_info).to eq({ memoized: true })
  end

  describe 'when profile attributes are present' do
    it 'combines address1 and address2 correctly' do
      expected_address = '123 Main St, Apt 4'
      expect(partner.agency_info[:address]).to eq(expected_address)
    end

    it 'returns correct city' do
      expect(partner.agency_info[:city]).to eq('Metropolis')
    end

    it 'returns correct state' do
      expect(partner.agency_info[:state]).to eq('NY')
    end

    it 'returns correct zip_code' do
      expect(partner.agency_info[:zip_code]).to eq('12345')
    end

    it 'returns correct website' do
      expect(partner.agency_info[:website]).to eq('http://example.com')
    end
  end

  describe 'when profile.agency_type is :other' do
    let(:agency_type) { 'other' }

    it 'appends other_agency_type to the translated string' do
      translated_type = I18n.t(:other, scope: :partners_profile)
      expected_agency_type = "#{translated_type}: Custom Agency"
      expect(partner.agency_info[:agency_type]).to eq(expected_agency_type)
    end
  end

  describe 'when profile.agency_type is not :other' do
    it 'translates the agency type correctly' do
      translated_type = I18n.t(:career, scope: :partners_profile)
      expect(partner.agency_info[:agency_type]).to eq(translated_type)
    end
  end
end
describe "#deletable?" do
  let(:partner) { build(:partner, :uninvited) }
  let(:invited_partner) { build(:partner, status: :invited) }
  let(:partner_with_distributions) { build(:partner, :uninvited, distributions: [build(:distribution)]) }
  let(:partner_with_requests) { build(:partner, :uninvited, requests: [build(:request)]) }
  let(:partner_with_users) do
    partner = build(:partner, :uninvited)
    user = build(:partner_user)
    user.roles << build(:role, resource: partner)
    partner.users << user
    partner
  end

  it "returns true when uninvited, no distributions, no requests, and no users" do
    expect(partner.deletable?).to be true
  end

  it "returns false when invited" do
    expect(invited_partner.deletable?).to be false
  end

  it "returns false when there are distributions" do
    expect(partner_with_distributions.deletable?).to be false
  end

  it "returns false when there are requests" do
    expect(partner_with_requests.deletable?).to be false
  end

  it "returns false when there are users" do
    expect(partner_with_users.deletable?).to be false
  end
end
describe '#approvable?', :phoenix do
  let(:partner_invited) { build(:partner, status: :invited) }
  let(:partner_awaiting_review) { build(:partner, status: :awaiting_review) }
  let(:partner_neither) { build(:partner, status: :uninvited) }

  it 'returns true if the partner is invited' do
    expect(partner_invited.approvable?).to eq(true)
  end

  it 'returns true if the partner is awaiting review' do
    expect(partner_awaiting_review.approvable?).to eq(true)
  end

  it 'returns false if the partner is neither invited nor awaiting review' do
    expect(partner_neither.approvable?).to eq(false)
  end
end
describe '#primary_user' do
    let(:partner) { create(:partner) }

    context 'when there are no users' do
      it 'returns nil' do
        expect(partner.primary_user).to be_nil
      end
    end

    context 'when there is only one user' do
      let!(:user) { create(:user, partner: partner) }

      it 'returns the user' do
        expect(partner.primary_user).to eq(user)
      end
    end

    context 'when there are multiple users' do
      let!(:user1) { create(:user, partner: partner, created_at: 2.days.ago) }
      let!(:user2) { create(:user, partner: partner, created_at: 1.day.ago) }

      it 'returns the earliest created user' do
        expect(partner.primary_user).to eq(user1)
      end
    end

    context 'when multiple users have the same creation date' do
      let!(:user1) { create(:user, partner: partner, created_at: 1.day.ago) }
      let!(:user2) { create(:user, partner: partner, created_at: 1.day.ago) }

      it 'returns one user' do
        expect([user1, user2]).to include(partner.primary_user)
      end
    end
  end
describe "#partials_to_show" do
  let(:organization_with_fields) { build(:organization, partner_form_fields: ['field1', 'field2']) }
  let(:organization_without_fields) { build(:organization, partner_form_fields: []) }

  context "when partner form fields are present" do
    before do
      allow(subject).to receive(:organization).and_return(organization_with_fields)
    end

    it "returns the partner form fields" do
      expect(subject.partials_to_show).to eq(['field1', 'field2'])
    end
  end

  context "when partner form fields are not present" do
    before do
      allow(subject).to receive(:organization).and_return(organization_without_fields)
    end

    it "returns ALL_PARTIALS" do
      expect(subject.partials_to_show).to eq(Partner::ALL_PARTIALS)
    end
  end
end
describe "#quota_exceeded?", :phoenix do
  let(:partner_with_quota) { build(:partner, quota: 100) }
  let(:partner_without_quota) { build(:partner, quota: nil) }

  it "returns true when total is greater than quota" do
    total = 150
    expect(partner_with_quota.quota_exceeded?(total)).to be true
  end

  it "returns false when total is equal to quota" do
    total = 100
    expect(partner_with_quota.quota_exceeded?(total)).to be false
  end

  it "returns false when total is less than quota" do
    total = 50
    expect(partner_with_quota.quota_exceeded?(total)).to be false
  end

  it "returns false when quota is not present" do
    total = 150
    expect(partner_without_quota.quota_exceeded?(total)).to be false
  end
end
describe '#display_status' do
  let(:partner_awaiting_review) { build(:partner, status: :awaiting_review) }
  let(:partner_uninvited) { build(:partner, status: :uninvited) }
  let(:partner_approved) { build(:partner, status: :approved) }
  let(:partner_deactivated) { build(:partner, status: :deactivated) } # Use a valid status

  it 'returns Submitted when status is :awaiting_review' do
    expect(partner_awaiting_review.display_status).to eq('Submitted'.encode('UTF-8'))
  end

  it 'returns Pending when status is :uninvited' do
    expect(partner_uninvited.display_status).to eq('Pending'.encode('UTF-8'))
  end

  it 'returns Verified when status is :approved' do
    expect(partner_approved.display_status).to eq('Verified'.encode('UTF-8'))
  end

  it 'titleizes the status for any other status' do
    expect(partner_deactivated.display_status).to eq('Deactivated'.encode('UTF-8'))
  end
end
end
