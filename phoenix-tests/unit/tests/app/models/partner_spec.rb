
require "rails_helper"

RSpec.describe Partner do
describe '#agency_info', :phoenix do
  let(:partner) { create(:partner) }
  let(:profile) { create(:partner_profile, partner: partner, address1: '123 Main St'.encode('UTF-8'), address2: 'Apt 4'.encode('UTF-8'), city: 'Metropolis', state: 'NY', zip_code: '12345', website: 'http://example.com', agency_type: agency_type, other_agency_type: 'Custom Agency') }
  let(:agency_type) { nil }

  it 'returns memoized @agency_info if already set' do
    partner.instance_variable_set(:@agency_info, { memoized: true })
    expect(partner.agency_info).to eq({ memoized: true })
  end

  it 'concatenates address1 and address2 if present' do
    expect(partner.agency_info[:address]).to eq('123 Main St, Apt 4')
  end

  it 'assigns city from profile' do
    expect(partner.agency_info[:city]).to eq('Metropolis')
  end

  it 'assigns state from profile' do
    expect(partner.agency_info[:state]).to eq('NY')
  end

  it 'assigns zip code from profile' do
    expect(partner.agency_info[:zip_code]).to eq('12345')
  end

  it 'assigns website from profile' do
    expect(partner.agency_info[:website]).to eq('http://example.com')
  end

  describe 'when agency_type is nil' do
    let(:agency_type) { nil }

    it 'handles nil agency_type gracefully' do
      expect(partner.agency_info[:agency_type]).to eq(I18n.t(nil, scope: :partners_profile))
    end
  end

  describe 'when agency_type is :other' do
    let(:agency_type) { 'other' }

    it 'appends other_agency_type to the translated string' do
      expect(partner.agency_info[:agency_type]).to eq("#{I18n.t(:other, scope: :partners_profile)}: Custom Agency")
    end
  end

  describe 'when agency_type is not :other' do
    let(:agency_type) { 'government' }

    it 'translates the agency type' do
      expect(partner.agency_info[:agency_type]).to eq(I18n.t(:government, scope: :partners_profile))
    end
  end
end
describe "#display_status", :phoenix do
    let(:partner_awaiting_review) { build(:partner, :awaiting_review) }
    let(:partner_uninvited) { build(:partner, :uninvited) }
    let(:partner_approved) { build(:partner, :approved) }
    let(:partner_other_status) { build(:partner, status: :inactive) } # Changed to a valid status

    it "returns 'Awaiting Review' when status is :awaiting_review" do
      expect(partner_awaiting_review.display_status).to eq('Awaiting Review')
    end

    it "returns 'Uninvited' when status is :uninvited" do
      expect(partner_uninvited.display_status).to eq('Uninvited')
    end

    it "returns 'Approved' when status is :approved" do
      expect(partner_approved.display_status).to eq('Approved')
    end

    it "returns the titleized status for any other status" do
      expect(partner_other_status.display_status).to eq('Inactive')
    end
  end
describe '#impact_metrics', :phoenix do
  let(:partner) { create(:partner) }
  let(:family) { create(:partners_family, partner: partner) }
  let(:child) { create(:partners_child, family: family) }

  it 'returns a hash with all keys present' do
    expect(partner.impact_metrics.keys).to contain_exactly(:families_served, :children_served, :family_zipcodes, :family_zipcodes_list)
  end

  context 'when there are no families' do
    before do
      allow(partner).to receive(:families).and_return([])
    end

    it 'returns families_served as 0' do
      expect(partner.impact_metrics[:families_served]).to eq(0)
    end

    it 'returns family_zipcodes as 0' do
      expect(partner.impact_metrics[:family_zipcodes]).to eq(0)
    end

    it 'returns family_zipcodes_list as an empty array' do
      expect(partner.impact_metrics[:family_zipcodes_list]).to eq([])
    end
  end

  context 'when there are no children' do
    before do
      allow(family).to receive(:children).and_return([])
    end

    it 'returns children_served as 0' do
      expect(partner.impact_metrics[:children_served]).to eq(0)
    end
  end

  context 'with large datasets' do
    let(:large_number_of_families) { create_list(:partners_family, 1000, partner: partner) }
    let(:large_number_of_children) { create_list(:partners_child, 1000, family: family) }

    before do
      allow(partner).to receive(:families).and_return(large_number_of_families)
      allow(family).to receive(:children).and_return(large_number_of_children)
    end

    it 'handles large number of families' do
      expect(partner.impact_metrics[:families_served]).to eq(1000)
    end

    it 'handles large number of children' do
      expect(partner.impact_metrics[:children_served]).to eq(1000)
    end
  end

  context 'with zip code data' do
    let(:same_zip_code_families) { create_list(:partners_family, 5, partner: partner, guardian_zip_code: '12345') }
    let(:unique_zip_code_families) { create_list(:partners_family, 5, partner: partner) { |family, i| family.guardian_zip_code = "1234#{i}" } }
    let(:malformed_zip_code_families) { create_list(:partners_family, 5, partner: partner, guardian_zip_code: '00000') }

    before do
      allow(partner).to receive(:families).and_return(same_zip_code_families + unique_zip_code_families + malformed_zip_code_families)
    end

    it 'handles all families having the same zip code' do
      expect(partner.impact_metrics[:family_zipcodes]).to eq(6)
    end

    it 'handles each family having a unique zip code' do
      expect(partner.impact_metrics[:family_zipcodes_list].sort).to eq(['12345', '12340', '12341', '12342', '12343', '12344'])
    end

    it 'handles nil or malformed zip codes gracefully' do
      expect(partner.impact_metrics[:family_zipcodes_list]).not_to include('00000')
    end
  end
end
describe '#import_csv', :phoenix do
  let(:organization) { create(:organization) }
  let(:csv) { CSV.parse(csv_data, headers: true) }
  let(:csv_data) { "name,email\nPartner Name,partner@example.com" }

  it 'successfully imports a CSV row and increases Partner count' do
    expect { Partner.import_csv(csv, organization.id) }.to change { Partner.count }.by(1)
  end

  it 'handles errors when PartnerCreateService fails' do
    allow_any_instance_of(PartnerCreateService).to receive(:call).and_return(double(success?: false, errors: ['Partner Name: Error']))
    errors = Partner.import_csv(csv, organization.id)
    expect(errors).to include('Partner Name: Error')
  end

  it 'raises an error when organization is not found' do
    expect { Partner.import_csv(csv, -1) }.to raise_error(ActiveRecord::RecordNotFound)
  end

  context 'when CSV is empty' do
    let(:csv_data) { "" }

    it 'returns no errors' do
      errors = Partner.import_csv(csv, organization.id)
      expect(errors).to be_empty
    end
  end

  context 'when CSV has invalid data format' do
    let(:csv_data) { "invalid,data" }

    it 'returns errors for invalid data' do
      allow(Partner).to receive(:validate_csv_data).and_return(['Invalid data format'])
      errors = Partner.import_csv(csv, organization.id)
      expect(errors).not_to be_empty
    end
  end
end
describe '#primary_user', :phoenix do
  let(:partner) { create(:partner) }

  context 'when there are no users' do
    before do
      partner.users.destroy_all
    end

    it 'returns nil' do
      expect(partner.primary_user).to be_nil
    end
  end

  context 'when there is one user' do
    let!(:user) { create(:partner_user, partner: partner) }

    it 'returns the only user' do
      expect(partner.primary_user).to eq(user)
    end
  end

  context 'when there are multiple users' do
    let!(:first_user) { create(:partner_user, partner: partner, created_at: 2.days.ago) }
    let!(:second_user) { create(:partner_user, partner: partner, created_at: 1.day.ago) }

    it 'returns the first created user' do
      expect(partner.primary_user).to eq(first_user)
    end
  end
end
describe '#quantity_year_to_date', :phoenix do
  let(:partner) { create(:partner) }
  let(:organization) { create(:organization) }

  context 'when there are no distributions in the current year' do
    it 'returns zero' do
      expect(partner.quantity_year_to_date).to eq(0)
    end
  end

  context 'when distributions exist but have no line items' do
    let!(:distribution) { create(:distribution, partner: partner, organization: organization, issued_at: Time.zone.today.beginning_of_year) }

    it 'returns zero' do
      expect(partner.quantity_year_to_date).to eq(0)
    end
  end

  context 'when distributions have line items with zero quantity' do
    let!(:distribution) { create(:distribution, partner: partner, organization: organization, issued_at: Time.zone.today.beginning_of_year) }
    let!(:line_item) { create(:line_item, quantity: 0, itemizable: distribution) }

    it 'returns zero' do
      expect(partner.quantity_year_to_date).to eq(0)
    end
  end

  context 'when distributions have line items with negative quantities' do
    let!(:distribution) { create(:distribution, partner: partner, organization: organization, issued_at: Time.zone.today.beginning_of_year) }
    let!(:line_item) { create(:line_item, quantity: -5, itemizable: distribution) }

    it 'calculates the total correctly' do
      expect(partner.quantity_year_to_date).to eq(-5)
    end
  end

  context 'when handling the date range' do
    let!(:distribution) { create(:distribution, partner: partner, organization: organization, issued_at: Time.zone.today.beginning_of_year - 1.day) }

    it 'includes only distributions from the beginning of the year' do
      expect(partner.quantity_year_to_date).to eq(0)
    end
  end

  context 'when fetching associated line items' do
    let!(:distribution) { create(:distribution, partner: partner, organization: organization, issued_at: Time.zone.today.beginning_of_year) }
    let!(:line_item) { create(:line_item, quantity: 10, itemizable: distribution) }

    it 'correctly includes and references line items' do
      expect(partner.quantity_year_to_date).to eq(10)
    end
  end
end
describe "#display_status", :phoenix do
    let(:partner_awaiting_review) { build(:partner, :awaiting_review) }
    let(:partner_uninvited) { build(:partner, :uninvited) }
    let(:partner_approved) { build(:partner, :approved) }
    let(:partner_other_status) { build(:partner, status: :inactive) } # Changed to a valid status

    it "returns 'Awaiting Review' when status is :awaiting_review" do
      expect(partner_awaiting_review.display_status).to eq('Awaiting Review')
    end

    it "returns 'Uninvited' when status is :uninvited" do
      expect(partner_uninvited.display_status).to eq('Uninvited')
    end

    it "returns 'Approved' when status is :approved" do
      expect(partner_approved.display_status).to eq('Approved')
    end

    it "returns the titleized status for any other status" do
      expect(partner_other_status.display_status).to eq('Inactive')
    end
  end
describe '#quantity_year_to_date', :phoenix do
  let(:partner) { create(:partner) }
  let(:organization) { create(:organization) }

  context 'when there are no distributions in the current year' do
    it 'returns zero' do
      expect(partner.quantity_year_to_date).to eq(0)
    end
  end

  context 'when distributions exist but have no line items' do
    let!(:distribution) { create(:distribution, partner: partner, organization: organization, issued_at: Time.zone.today.beginning_of_year) }

    it 'returns zero' do
      expect(partner.quantity_year_to_date).to eq(0)
    end
  end

  context 'when distributions have line items with zero quantity' do
    let!(:distribution) { create(:distribution, partner: partner, organization: organization, issued_at: Time.zone.today.beginning_of_year) }
    let!(:line_item) { create(:line_item, quantity: 0, itemizable: distribution) }

    it 'returns zero' do
      expect(partner.quantity_year_to_date).to eq(0)
    end
  end

  context 'when distributions have line items with negative quantities' do
    let!(:distribution) { create(:distribution, partner: partner, organization: organization, issued_at: Time.zone.today.beginning_of_year) }
    let!(:line_item) { create(:line_item, quantity: -5, itemizable: distribution) }

    it 'calculates the total correctly' do
      expect(partner.quantity_year_to_date).to eq(-5)
    end
  end

  context 'when handling the date range' do
    let!(:distribution) { create(:distribution, partner: partner, organization: organization, issued_at: Time.zone.today.beginning_of_year - 1.day) }

    it 'includes only distributions from the beginning of the year' do
      expect(partner.quantity_year_to_date).to eq(0)
    end
  end

  context 'when fetching associated line items' do
    let!(:distribution) { create(:distribution, partner: partner, organization: organization, issued_at: Time.zone.today.beginning_of_year) }
    let!(:line_item) { create(:line_item, quantity: 10, itemizable: distribution) }

    it 'correctly includes and references line items' do
      expect(partner.quantity_year_to_date).to eq(10)
    end
  end
end
describe "#quota_exceeded?", :phoenix do
  let(:partner_with_quota) { build(:partner, quota: 100) }
  let(:partner_without_quota) { build(:partner, quota: nil) }

  it "returns true when total is greater than quota" do
    expect(partner_with_quota.quota_exceeded?(101)).to eq(true)
  end

  it "returns false when total is equal to quota" do
    expect(partner_with_quota.quota_exceeded?(100)).to eq(false)
  end

  it "returns false when total is less than quota" do
    expect(partner_with_quota.quota_exceeded?(99)).to eq(false)
  end

  it "returns false when quota is not present" do
    expect(partner_without_quota.quota_exceeded?(50)).to eq(false)
  end
end
describe '#agency_info', :phoenix do
  let(:partner) { create(:partner) }
  let(:profile) { create(:partner_profile, partner: partner, address1: '123 Main St'.encode('UTF-8'), address2: 'Apt 4'.encode('UTF-8'), city: 'Metropolis', state: 'NY', zip_code: '12345', website: 'http://example.com', agency_type: agency_type, other_agency_type: 'Custom Agency') }
  let(:agency_type) { nil }

  it 'returns memoized @agency_info if already set' do
    partner.instance_variable_set(:@agency_info, { memoized: true })
    expect(partner.agency_info).to eq({ memoized: true })
  end

  it 'concatenates address1 and address2 if present' do
    expect(partner.agency_info[:address]).to eq('123 Main St, Apt 4')
  end

  it 'assigns city from profile' do
    expect(partner.agency_info[:city]).to eq('Metropolis')
  end

  it 'assigns state from profile' do
    expect(partner.agency_info[:state]).to eq('NY')
  end

  it 'assigns zip code from profile' do
    expect(partner.agency_info[:zip_code]).to eq('12345')
  end

  it 'assigns website from profile' do
    expect(partner.agency_info[:website]).to eq('http://example.com')
  end

  describe 'when agency_type is nil' do
    let(:agency_type) { nil }

    it 'handles nil agency_type gracefully' do
      expect(partner.agency_info[:agency_type]).to eq(I18n.t(nil, scope: :partners_profile))
    end
  end

  describe 'when agency_type is :other' do
    let(:agency_type) { 'other' }

    it 'appends other_agency_type to the translated string' do
      expect(partner.agency_info[:agency_type]).to eq("#{I18n.t(:other, scope: :partners_profile)}: Custom Agency")
    end
  end

  describe 'when agency_type is not :other' do
    let(:agency_type) { 'government' }

    it 'translates the agency type' do
      expect(partner.agency_info[:agency_type]).to eq(I18n.t(:government, scope: :partners_profile))
    end
  end
end
describe '#approvable?', :phoenix do
  let(:partner_invited) { build(:partner, status: :invited) }
  let(:partner_awaiting_review) { build(:partner, status: :awaiting_review) }
  let(:partner_uninvited) { build(:partner, status: :uninvited) }
  let(:partner_approved) { build(:partner, status: :approved) }
  let(:partner_recertification_required) { build(:partner, status: :recertification_required) }
  let(:partner_deactivated) { build(:partner, status: :deactivated) }

  it 'returns true when status is invited' do
    expect(partner_invited.approvable?).to eq(true)
  end

  it 'returns true when status is awaiting_review' do
    expect(partner_awaiting_review.approvable?).to eq(true)
  end

  it 'returns false when status is uninvited' do
    expect(partner_uninvited.approvable?).to eq(false)
  end

  it 'returns false when status is approved' do
    expect(partner_approved.approvable?).to eq(false)
  end

  it 'returns false when status is recertification_required' do
    expect(partner_recertification_required.approvable?).to eq(false)
  end

  it 'returns false when status is deactivated' do
    expect(partner_deactivated.approvable?).to eq(false)
  end
end
describe '#primary_user', :phoenix do
  let(:partner) { create(:partner) }

  context 'when there are no users' do
    before do
      partner.users.destroy_all
    end

    it 'returns nil' do
      expect(partner.primary_user).to be_nil
    end
  end

  context 'when there is one user' do
    let!(:user) { create(:partner_user, partner: partner) }

    it 'returns the only user' do
      expect(partner.primary_user).to eq(user)
    end
  end

  context 'when there are multiple users' do
    let!(:first_user) { create(:partner_user, partner: partner, created_at: 2.days.ago) }
    let!(:second_user) { create(:partner_user, partner: partner, created_at: 1.day.ago) }

    it 'returns the first created user' do
      expect(partner.primary_user).to eq(first_user)
    end
  end
end
describe "#contact_person", :phoenix do
  let(:partner) { build(:partner) }
  let(:profile) { build(:partner_profile, partner: partner) }

  context "when @contact_person is already set" do
    before do
      partner.instance_variable_set(:@contact_person, { name: "John Doe", email: "john.doe@example.com", phone: "1234567890" })
    end

    it "returns the existing @contact_person" do
      expect(partner.contact_person).to eq({ name: "John Doe", email: "john.doe@example.com", phone: "1234567890" })
    end
  end

  describe "when @contact_person is not set" do
    before do
      allow(partner).to receive(:profile).and_return(profile)
    end

    it "constructs a new contact person hash with primary contact name" do
      allow(profile).to receive(:primary_contact_name).and_return("Jane Smith")
      expect(partner.contact_person[:name]).to eq("Jane Smith")
    end

    it "constructs a new contact person hash with primary contact email" do
      allow(profile).to receive(:primary_contact_email).and_return("jane.smith@example.com")
      expect(partner.contact_person[:email]).to eq("jane.smith@example.com")
    end

    it "constructs a new contact person hash with primary contact phone if available" do
      allow(profile).to receive(:primary_contact_phone).and_return("0987654321")
      expect(partner.contact_person[:phone]).to eq("0987654321")
    end

    it "constructs a new contact person hash with primary contact mobile if phone is not available" do
      allow(profile).to receive(:primary_contact_phone).and_return(nil)
      allow(profile).to receive(:primary_contact_mobile).and_return("1122334455")
      expect(partner.contact_person[:phone]).to eq("1122334455")
    end
  end
end
describe '#import_csv', :phoenix do
  let(:organization) { create(:organization) }
  let(:csv) { CSV.parse(csv_data, headers: true) }
  let(:csv_data) { "name,email\nPartner Name,partner@example.com" }

  it 'successfully imports a CSV row and increases Partner count' do
    expect { Partner.import_csv(csv, organization.id) }.to change { Partner.count }.by(1)
  end

  it 'handles errors when PartnerCreateService fails' do
    allow_any_instance_of(PartnerCreateService).to receive(:call).and_return(double(success?: false, errors: ['Partner Name: Error']))
    errors = Partner.import_csv(csv, organization.id)
    expect(errors).to include('Partner Name: Error')
  end

  it 'raises an error when organization is not found' do
    expect { Partner.import_csv(csv, -1) }.to raise_error(ActiveRecord::RecordNotFound)
  end

  context 'when CSV is empty' do
    let(:csv_data) { "" }

    it 'returns no errors' do
      errors = Partner.import_csv(csv, organization.id)
      expect(errors).to be_empty
    end
  end

  context 'when CSV has invalid data format' do
    let(:csv_data) { "invalid,data" }

    it 'returns errors for invalid data' do
      allow(Partner).to receive(:validate_csv_data).and_return(['Invalid data format'])
      errors = Partner.import_csv(csv, organization.id)
      expect(errors).not_to be_empty
    end
  end
end
describe "#deletable?", :phoenix do
  let(:partner) { build(:partner, :uninvited) }
  let(:distributions) { [] }
  let(:requests) { [] }
  let(:users) { [] }

  before do
    allow(partner).to receive(:distributions).and_return(distributions)
    allow(partner).to receive(:requests).and_return(requests)
    allow(partner).to receive(:users).and_return(users)
  end

  it "returns true when uninvited and has no distributions, requests, or users" do
    expect(partner.deletable?).to eq(true)
  end

  describe "when not uninvited" do
    let(:partner) { build(:partner, :approved) }

    it "returns false" do
      expect(partner.deletable?).to eq(false)
    end
  end

  describe "when there are distributions" do
    let(:distributions) { [build(:distribution)] }

    it "returns false" do
      expect(partner.deletable?).to eq(false)
    end
  end

  describe "when there are requests" do
    let(:requests) { [build(:request)] }

    it "returns false" do
      expect(partner.deletable?).to eq(false)
    end
  end

  describe "when there are users" do
    let(:users) { [build(:user)] }

    it "returns false" do
      expect(partner.deletable?).to eq(false)
    end
  end
end
describe "#partials_to_show", :phoenix do
  let(:organization) { build(:organization) }
  let(:partner) { build(:partner, organization: organization) }

  before do
    allow(organization).to receive(:partner_form_fields).and_return(partner_form_fields)
  end

  context "when partner form fields are present" do
    let(:partner_form_fields) { ['field1', 'field2'] }

    it "returns partner form fields" do
      expect(partner.partials_to_show).to eq(partner_form_fields)
    end
  end

  context "when partner form fields are not present" do
    let(:partner_form_fields) { nil }

    it "returns ALL_PARTIALS" do
      expect(partner.partials_to_show).to eq(Partner::ALL_PARTIALS)
    end
  end
end
describe '#impact_metrics', :phoenix do
  let(:partner) { create(:partner) }
  let(:family) { create(:partners_family, partner: partner) }
  let(:child) { create(:partners_child, family: family) }

  it 'returns a hash with all keys present' do
    expect(partner.impact_metrics.keys).to contain_exactly(:families_served, :children_served, :family_zipcodes, :family_zipcodes_list)
  end

  context 'when there are no families' do
    before do
      allow(partner).to receive(:families).and_return([])
    end

    it 'returns families_served as 0' do
      expect(partner.impact_metrics[:families_served]).to eq(0)
    end

    it 'returns family_zipcodes as 0' do
      expect(partner.impact_metrics[:family_zipcodes]).to eq(0)
    end

    it 'returns family_zipcodes_list as an empty array' do
      expect(partner.impact_metrics[:family_zipcodes_list]).to eq([])
    end
  end

  context 'when there are no children' do
    before do
      allow(family).to receive(:children).and_return([])
    end

    it 'returns children_served as 0' do
      expect(partner.impact_metrics[:children_served]).to eq(0)
    end
  end

  context 'with large datasets' do
    let(:large_number_of_families) { create_list(:partners_family, 1000, partner: partner) }
    let(:large_number_of_children) { create_list(:partners_child, 1000, family: family) }

    before do
      allow(partner).to receive(:families).and_return(large_number_of_families)
      allow(family).to receive(:children).and_return(large_number_of_children)
    end

    it 'handles large number of families' do
      expect(partner.impact_metrics[:families_served]).to eq(1000)
    end

    it 'handles large number of children' do
      expect(partner.impact_metrics[:children_served]).to eq(1000)
    end
  end

  context 'with zip code data' do
    let(:same_zip_code_families) { create_list(:partners_family, 5, partner: partner, guardian_zip_code: '12345') }
    let(:unique_zip_code_families) { create_list(:partners_family, 5, partner: partner) { |family, i| family.guardian_zip_code = "1234#{i}" } }
    let(:malformed_zip_code_families) { create_list(:partners_family, 5, partner: partner, guardian_zip_code: '00000') }

    before do
      allow(partner).to receive(:families).and_return(same_zip_code_families + unique_zip_code_families + malformed_zip_code_families)
    end

    it 'handles all families having the same zip code' do
      expect(partner.impact_metrics[:family_zipcodes]).to eq(6)
    end

    it 'handles each family having a unique zip code' do
      expect(partner.impact_metrics[:family_zipcodes_list].sort).to eq(['12345', '12340', '12341', '12342', '12343', '12344'])
    end

    it 'handles nil or malformed zip codes gracefully' do
      expect(partner.impact_metrics[:family_zipcodes_list]).not_to include('00000')
    end
  end
end
end
