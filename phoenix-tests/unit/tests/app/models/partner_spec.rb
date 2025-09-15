
require "rails_helper"

RSpec.describe Partner do
describe '#agency_info', :phoenix do
  let(:partner) { build(:partner) }
  let(:profile) { build(:partner_profile, partner: partner, agency_type: agency_type, address1: address1, address2: address2, city: 'Test City', state: 'TS', zip_code: '12345', website: 'http://example.com', other_agency_type: other_agency_type) }
  let(:agency_type) { nil }
  let(:address1) { nil }
  let(:address2) { nil }
  let(:other_agency_type) { nil }

  before do
    allow(partner).to receive(:profile).and_return(profile)
  end

  it 'returns cached @agency_info if already set' do
    partner.instance_variable_set(:@agency_info, { cached: true })
    expect(partner.agency_info).to eq({ cached: true })
  end

  context 'when profile.agency_type is nil' do
    it 'handles nil agency_type' do
      expect(partner.agency_info[:agency_type]).to be_nil
    end
  end

  context 'when profile.agency_type is :other' do
    let(:agency_type) { 'other' }
    let(:other_agency_type) { 'Custom Agency' }

    it 'includes other_agency_type in agency_type' do
      expect(partner.agency_info[:agency_type]).to eq('Other: Custom Agency')
    end
  end

  context 'when profile.agency_type is not :other' do
    let(:agency_type) { 'career' } # Changed from 'government' to 'career'

    it 'translates agency_type correctly' do
      expect(partner.agency_info[:agency_type]).to eq(I18n.t(:career, scope: :partners_profile))
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

    it 'uses only address1 in the address' do
      expect(partner.agency_info[:address]).to eq('123 Main St')
    end
  end

  context 'when only address2 is present' do
    let(:address2) { 'Apt 4' }

    it 'uses only address2 in the address' do
      expect(partner.agency_info[:address]).to eq('Apt 4')
    end
  end

  context 'when neither address1 nor address2 is present' do
    it 'results in an empty address' do
      expect(partner.agency_info[:address]).to eq('')
    end
  end
end
describe '#approvable?', :phoenix do
    let(:partner_invited) { build(:partner, status: :invited) }
    let(:partner_awaiting_review) { build(:partner, status: :awaiting_review) }
    let(:partner_both_true) { build(:partner, status: :awaiting_review) } # Since both true is not a valid state, use awaiting_review
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
describe '#display_status' do
  let(:partner_awaiting_review) { build(:partner, status: :awaiting_review) }
  let(:partner_uninvited) { build(:partner, status: :uninvited) }
  let(:partner_approved) { build(:partner, status: :approved) }
  let(:partner_deactivated) { build(:partner, status: :deactivated) }

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
      expect(partner_deactivated.display_status).to eq('Deactivated')
    end
  end
end
describe '#import_csv', :phoenix do
    let(:organization) { create(:organization) }
    let(:partner) { build(:partner, organization: organization) }
    let(:csv_row) { { 'name' => partner.name, 'email' => partner.email } }
    let(:csv) { [csv_row] }

    before do
      allow(Organization).to receive(:find).and_return(organization)
    end

    it 'successfully imports a CSV row' do
      allow(PartnerCreateService).to receive(:new).and_return(double(call: true, errors: []))
      errors = Partner.import_csv(csv, organization.id)
      expect(errors).to be_empty
    end

    it 'handles errors during the import process' do
      partner_double = double('Partner', name: 'Test Partner', errors: double(full_messages: ['Error message']))
      allow(PartnerCreateService).to receive(:new).and_return(double(call: false, errors: ['Error message'], partner: partner_double))
      errors = Partner.import_csv(csv, organization.id)
      expect(errors).to include('Test Partner: Error message')
    end

    describe 'when PartnerCreateService returns errors' do
      it 'collects error messages' do
        partner_double = double('Partner', name: partner.name, errors: double(full_messages: ['Name can\'t be blank']))
        allow(PartnerCreateService).to receive(:new).and_return(double(call: false, errors: ['Name can\'t be blank'], partner: partner_double))
        errors = Partner.import_csv(csv, organization.id)
        expect(errors).to include("#{partner.name}: Name can't be blank")
      end
    end

    it 'handles an empty CSV' do
      errors = Partner.import_csv([], organization.id)
      expect(errors).to be_empty
    end

    it 'handles case when organization is not found' do
      allow(Organization).to receive(:find).and_raise(ActiveRecord::RecordNotFound)
      expect { Partner.import_csv(csv, organization.id) }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
describe '#partials_to_show', :phoenix do
  let(:organization_with_fields) { build(:organization, partner_form_fields: ['field1', 'field2']) }
  let(:organization_without_fields) { build(:organization, partner_form_fields: nil) }
  let(:partner_with_fields) { Partner.new(organization: organization_with_fields) }
  let(:partner_without_fields) { Partner.new(organization: organization_without_fields) }
  let(:all_partials) { Partner::ALL_PARTIALS }

  context 'when organization.partner_form_fields is present' do
    it 'returns the partner form fields of the organization' do
      expect(partner_with_fields.partials_to_show).to eq(['field1', 'field2'])
    end
  end

  context 'when organization.partner_form_fields is not present' do
    it 'returns all partials' do
      expect(partner_without_fields.partials_to_show).to eq(all_partials)
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
    let!(:user) { create(:partner_user, partner: partner) }

    it 'returns the only user' do
      expect(partner.primary_user).to eq(user)
    end
  end

  context 'when there are multiple users' do
    let!(:user1) { create(:partner_user, partner: partner, created_at: 2.days.ago) }
    let!(:user2) { create(:partner_user, partner: partner, created_at: 1.day.ago) }

    it 'returns the first user by creation date' do
      expect(partner.primary_user).to eq(user1)
    end
  end

  context 'when users have the same creation date' do
    let!(:user1) { create(:partner_user, partner: partner, created_at: 1.day.ago) }
    let!(:user2) { create(:partner_user, partner: partner, created_at: 1.day.ago) }

    it 'returns one of the users' do
      expect([user1, user2]).to include(partner.primary_user)
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
    let!(:user) { create(:partner_user, partner: partner) }

    it 'returns the only user' do
      expect(partner.primary_user).to eq(user)
    end
  end

  context 'when there are multiple users' do
    let!(:user1) { create(:partner_user, partner: partner, created_at: 2.days.ago) }
    let!(:user2) { create(:partner_user, partner: partner, created_at: 1.day.ago) }

    it 'returns the first user by creation date' do
      expect(partner.primary_user).to eq(user1)
    end
  end

  context 'when users have the same creation date' do
    let!(:user1) { create(:partner_user, partner: partner, created_at: 1.day.ago) }
    let!(:user2) { create(:partner_user, partner: partner, created_at: 1.day.ago) }

    it 'returns one of the users' do
      expect([user1, user2]).to include(partner.primary_user)
    end
  end
end
describe "#deletable?", :phoenix do
  let(:partner) { build(:partner, :uninvited) }
  let(:distribution) { build(:distribution, partner: partner) }
  let(:request) { build(:request, partner: partner) }
  let(:user) { build(:partner_user, partner: partner) }

  it "returns true when uninvited, with no distributions, requests, or users" do
    allow(partner).to receive(:distributions).and_return([])
    allow(partner).to receive(:requests).and_return([])
    allow(partner).to receive(:users).and_return([])
    expect(partner.deletable?).to be true
  end

  context "when uninvited? is false" do
    before { allow(partner).to receive(:uninvited?).and_return(false) }

    it "returns false" do
      expect(partner.deletable?).to be false
    end
  end

  context "when distributions are present" do
    before { allow(partner).to receive(:distributions).and_return([distribution]) }

    it "returns false" do
      expect(partner.deletable?).to be false
    end
  end

  context "when requests are present" do
    before { allow(partner).to receive(:requests).and_return([request]) }

    it "returns false" do
      expect(partner.deletable?).to be false
    end
  end

  context "when users are present" do
    before { allow(partner).to receive(:users).and_return([user]) }

    it "returns false" do
      expect(partner.deletable?).to be false
    end
  end

  context "when uninvited? and distributions are false" do
    before do
      allow(partner).to receive(:uninvited?).and_return(false)
      allow(partner).to receive(:distributions).and_return([distribution])
    end

    it "returns false" do
      expect(partner.deletable?).to be false
    end
  end

  context "when uninvited? and requests are false" do
    before do
      allow(partner).to receive(:uninvited?).and_return(false)
      allow(partner).to receive(:requests).and_return([request])
    end

    it "returns false" do
      expect(partner.deletable?).to be false
    end
  end

  context "when uninvited? and users are false" do
    before do
      allow(partner).to receive(:uninvited?).and_return(false)
      allow(partner).to receive(:users).and_return([user])
    end

    it "returns false" do
      expect(partner.deletable?).to be false
    end
  end

  context "when distributions and requests are false" do
    before do
      allow(partner).to receive(:distributions).and_return([distribution])
      allow(partner).to receive(:requests).and_return([request])
    end

    it "returns false" do
      expect(partner.deletable?).to be false
    end
  end

  context "when distributions and users are false" do
    before do
      allow(partner).to receive(:distributions).and_return([distribution])
      allow(partner).to receive(:users).and_return([user])
    end

    it "returns false" do
      expect(partner.deletable?).to be false
    end
  end

  context "when requests and users are false" do
    before do
      allow(partner).to receive(:requests).and_return([request])
      allow(partner).to receive(:users).and_return([user])
    end

    it "returns false" do
      expect(partner.deletable?).to be false
    end
  end

  context "when uninvited?, distributions, and requests are false" do
    before do
      allow(partner).to receive(:uninvited?).and_return(false)
      allow(partner).to receive(:distributions).and_return([distribution])
      allow(partner).to receive(:requests).and_return([request])
    end

    it "returns false" do
      expect(partner.deletable?).to be false
    end
  end

  context "when uninvited?, distributions, and users are false" do
    before do
      allow(partner).to receive(:uninvited?).and_return(false)
      allow(partner).to receive(:distributions).and_return([distribution])
      allow(partner).to receive(:users).and_return([user])
    end

    it "returns false" do
      expect(partner.deletable?).to be false
    end
  end

  context "when uninvited?, requests, and users are false" do
    before do
      allow(partner).to receive(:uninvited?).and_return(false)
      allow(partner).to receive(:requests).and_return([request])
      allow(partner).to receive(:users).and_return([user])
    end

    it "returns false" do
      expect(partner.deletable?).to be false
    end
  end

  context "when distributions, requests, and users are false" do
    before do
      allow(partner).to receive(:distributions).and_return([distribution])
      allow(partner).to receive(:requests).and_return([request])
      allow(partner).to receive(:users).and_return([user])
    end

    it "returns false" do
      expect(partner.deletable?).to be false
    end
  end

  context "when all conditions are false" do
    before do
      allow(partner).to receive(:uninvited?).and_return(false)
      allow(partner).to receive(:distributions).and_return([distribution])
      allow(partner).to receive(:requests).and_return([request])
      allow(partner).to receive(:users).and_return([user])
    end

    it "returns false" do
      expect(partner.deletable?).to be false
    end
  end
end
describe '#approvable?', :phoenix do
    let(:partner_invited) { build(:partner, status: :invited) }
    let(:partner_awaiting_review) { build(:partner, status: :awaiting_review) }
    let(:partner_both_true) { build(:partner, status: :awaiting_review) } # Since both true is not a valid state, use awaiting_review
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
describe '#partials_to_show', :phoenix do
  let(:organization_with_fields) { build(:organization, partner_form_fields: ['field1', 'field2']) }
  let(:organization_without_fields) { build(:organization, partner_form_fields: nil) }
  let(:partner_with_fields) { Partner.new(organization: organization_with_fields) }
  let(:partner_without_fields) { Partner.new(organization: organization_without_fields) }
  let(:all_partials) { Partner::ALL_PARTIALS }

  context 'when organization.partner_form_fields is present' do
    it 'returns the partner form fields of the organization' do
      expect(partner_with_fields.partials_to_show).to eq(['field1', 'field2'])
    end
  end

  context 'when organization.partner_form_fields is not present' do
    it 'returns all partials' do
      expect(partner_without_fields.partials_to_show).to eq(all_partials)
    end
  end
end
describe '#agency_info', :phoenix do
  let(:partner) { build(:partner) }
  let(:profile) { build(:partner_profile, partner: partner, agency_type: agency_type, address1: address1, address2: address2, city: 'Test City', state: 'TS', zip_code: '12345', website: 'http://example.com', other_agency_type: other_agency_type) }
  let(:agency_type) { nil }
  let(:address1) { nil }
  let(:address2) { nil }
  let(:other_agency_type) { nil }

  before do
    allow(partner).to receive(:profile).and_return(profile)
  end

  it 'returns cached @agency_info if already set' do
    partner.instance_variable_set(:@agency_info, { cached: true })
    expect(partner.agency_info).to eq({ cached: true })
  end

  context 'when profile.agency_type is nil' do
    it 'handles nil agency_type' do
      expect(partner.agency_info[:agency_type]).to be_nil
    end
  end

  context 'when profile.agency_type is :other' do
    let(:agency_type) { 'other' }
    let(:other_agency_type) { 'Custom Agency' }

    it 'includes other_agency_type in agency_type' do
      expect(partner.agency_info[:agency_type]).to eq('Other: Custom Agency')
    end
  end

  context 'when profile.agency_type is not :other' do
    let(:agency_type) { 'career' } # Changed from 'government' to 'career'

    it 'translates agency_type correctly' do
      expect(partner.agency_info[:agency_type]).to eq(I18n.t(:career, scope: :partners_profile))
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

    it 'uses only address1 in the address' do
      expect(partner.agency_info[:address]).to eq('123 Main St')
    end
  end

  context 'when only address2 is present' do
    let(:address2) { 'Apt 4' }

    it 'uses only address2 in the address' do
      expect(partner.agency_info[:address]).to eq('Apt 4')
    end
  end

  context 'when neither address1 nor address2 is present' do
    it 'results in an empty address' do
      expect(partner.agency_info[:address]).to eq('')
    end
  end
end
describe '#contact_person', :phoenix do
  let(:partner) { build(:partner) }
  let(:profile) { partner.profile }

  it 'returns cached contact person if already set' do
    cached_contact_person = { name: 'John Doe', email: 'john@example.com', phone: '123-456-7890' }
    partner.instance_variable_set(:@contact_person, cached_contact_person)
    expect(partner.contact_person).to eq(cached_contact_person)
  end

  it 'creates a new contact person hash if not set' do
    allow(profile).to receive(:primary_contact_name).and_return('Jane Doe')
    allow(profile).to receive(:primary_contact_email).and_return('jane@example.com')
    allow(profile).to receive(:primary_contact_phone).and_return(nil)
    allow(profile).to receive(:primary_contact_mobile).and_return('098-765-4321')

    expected_contact_person = {
      name: 'Jane Doe',
      email: 'jane@example.com',
      phone: '098-765-4321'
    }
    expect(partner.contact_person).to eq(expected_contact_person)
  end

  describe 'when both phone and mobile are available' do
    before do
      allow(profile).to receive(:primary_contact_name).and_return('Alice Smith')
      allow(profile).to receive(:primary_contact_email).and_return('alice@example.com')
      allow(profile).to receive(:primary_contact_phone).and_return('123-456-7890')
      allow(profile).to receive(:primary_contact_mobile).and_return('098-765-4321')
    end

    it 'prefers phone over mobile' do
      expected_contact_person = {
        name: 'Alice Smith',
        email: 'alice@example.com',
        phone: '123-456-7890'
      }
      expect(partner.contact_person).to eq(expected_contact_person)
    end
  end

  describe 'when only mobile is available' do
    before do
      allow(profile).to receive(:primary_contact_name).and_return('Bob Brown')
      allow(profile).to receive(:primary_contact_email).and_return('bob@example.com')
      allow(profile).to receive(:primary_contact_phone).and_return(nil)
      allow(profile).to receive(:primary_contact_mobile).and_return('098-765-4321')
    end

    it 'uses mobile as phone' do
      expected_contact_person = {
        name: 'Bob Brown',
        email: 'bob@example.com',
        phone: '098-765-4321'
      }
      expect(partner.contact_person).to eq(expected_contact_person)
    end
  end
end
describe "#quantity_year_to_date", :phoenix do
  let(:partner) { create(:partner) }
  let(:organization) { partner.organization }
  let(:item) { create(:item, organization: organization) }

  let(:distribution_this_year) do
    create(:distribution, :with_items, item: item, item_quantity: 10, partner: partner, issued_at: Time.zone.today.beginning_of_year + 1.day)
  end

  let(:distribution_no_line_items) do
    create(:distribution, partner: partner, issued_at: Time.zone.today.beginning_of_year + 1.day)
  end

  let(:distribution_last_year) do
    create(:distribution, :with_items, item: item, item_quantity: 5, partner: partner, issued_at: Time.zone.today.beginning_of_year - 1.day)
  end

  let(:distribution_beginning_of_year) do
    create(:distribution, :with_items, item: item, item_quantity: 15, partner: partner, issued_at: Time.zone.today.beginning_of_year)
  end

  it "sums quantities for distributions issued this year" do
    distribution_this_year
    expect(partner.quantity_year_to_date).to eq(10)
  end

  it "returns zero for distributions without line items" do
    distribution_no_line_items
    expect(partner.quantity_year_to_date).to eq(0)
  end

  it "returns zero when no distributions issued this year" do
    distribution_last_year
    expect(partner.quantity_year_to_date).to eq(0)
  end

  it "sums quantities for distributions issued at the beginning of the year" do
    distribution_beginning_of_year
    expect(partner.quantity_year_to_date).to eq(15)
  end
end
describe '#impact_metrics', :phoenix do
  let(:partner) { build(:partner) }

  it 'returns correct families_served count' do
    allow(partner).to receive(:families_served_count).and_return(10)
    expect(partner.impact_metrics[:families_served]).to eq(10)
  end

  it 'returns correct children_served count' do
    allow(partner).to receive(:children_served_count).and_return(20)
    expect(partner.impact_metrics[:children_served]).to eq(20)
  end

  it 'returns correct family_zipcodes count' do
    allow(partner).to receive(:family_zipcodes_count).and_return(5)
    expect(partner.impact_metrics[:family_zipcodes]).to eq(5)
  end

  it 'returns correct family_zipcodes list' do
    allow(partner).to receive(:family_zipcodes_list).and_return(['12345', '67890'])
    expect(partner.impact_metrics[:family_zipcodes_list]).to eq(['12345', '67890'])
  end

  describe 'when families_served_count returns nil' do
    before do
      allow(partner).to receive(:families_served_count).and_return(nil)
    end

    it 'handles nil families_served_count' do
      expect(partner.impact_metrics[:families_served]).to be_nil
    end
  end

  describe 'when children_served_count returns nil' do
    before do
      allow(partner).to receive(:children_served_count).and_return(nil)
    end

    it 'handles nil children_served_count' do
      expect(partner.impact_metrics[:children_served]).to be_nil
    end
  end

  describe 'when family_zipcodes_count returns nil' do
    before do
      allow(partner).to receive(:family_zipcodes_count).and_return(nil)
    end

    it 'handles nil family_zipcodes_count' do
      expect(partner.impact_metrics[:family_zipcodes]).to be_nil
    end
  end

  describe 'when family_zipcodes_list returns nil' do
    before do
      allow(partner).to receive(:family_zipcodes_list).and_return(nil)
    end

    it 'handles nil family_zipcodes_list' do
      expect(partner.impact_metrics[:family_zipcodes_list]).to be_nil
    end
  end

  describe 'when families_served_count raises an exception' do
    before do
      allow(partner).to receive(:families_served_count).and_raise(StandardError)
    end

    it 'handles exception in families_served_count' do
      expect { partner.impact_metrics }.to raise_error(StandardError)
    end
  end

  describe 'when children_served_count raises an exception' do
    before do
      allow(partner).to receive(:children_served_count).and_raise(StandardError)
    end

    it 'handles exception in children_served_count' do
      expect { partner.impact_metrics }.to raise_error(StandardError)
    end
  end

  describe 'when family_zipcodes_count raises an exception' do
    before do
      allow(partner).to receive(:family_zipcodes_count).and_raise(StandardError)
    end

    it 'handles exception in family_zipcodes_count' do
      expect { partner.impact_metrics }.to raise_error(StandardError)
    end
  end

  describe 'when family_zipcodes_list raises an exception' do
    before do
      allow(partner).to receive(:family_zipcodes_list).and_raise(StandardError)
    end

    it 'handles exception in family_zipcodes_list' do
      expect { partner.impact_metrics }.to raise_error(StandardError)
    end
  end
end
describe '#quota_exceeded?', :phoenix do
  let(:partner_with_quota) { build(:partner, quota: 100) }
  let(:partner_without_quota) { build(:partner, quota: nil) }

  context 'when quota is present' do
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
  end

  context 'when quota is not present' do
    it 'returns false regardless of total' do
      total = 150
      expect(partner_without_quota.quota_exceeded?(total)).to be false
    end
  end
end
describe '#import_csv', :phoenix do
    let(:organization) { create(:organization) }
    let(:partner) { build(:partner, organization: organization) }
    let(:csv_row) { { 'name' => partner.name, 'email' => partner.email } }
    let(:csv) { [csv_row] }

    before do
      allow(Organization).to receive(:find).and_return(organization)
    end

    it 'successfully imports a CSV row' do
      allow(PartnerCreateService).to receive(:new).and_return(double(call: true, errors: []))
      errors = Partner.import_csv(csv, organization.id)
      expect(errors).to be_empty
    end

    it 'handles errors during the import process' do
      partner_double = double('Partner', name: 'Test Partner', errors: double(full_messages: ['Error message']))
      allow(PartnerCreateService).to receive(:new).and_return(double(call: false, errors: ['Error message'], partner: partner_double))
      errors = Partner.import_csv(csv, organization.id)
      expect(errors).to include('Test Partner: Error message')
    end

    describe 'when PartnerCreateService returns errors' do
      it 'collects error messages' do
        partner_double = double('Partner', name: partner.name, errors: double(full_messages: ['Name can\'t be blank']))
        allow(PartnerCreateService).to receive(:new).and_return(double(call: false, errors: ['Name can\'t be blank'], partner: partner_double))
        errors = Partner.import_csv(csv, organization.id)
        expect(errors).to include("#{partner.name}: Name can't be blank")
      end
    end

    it 'handles an empty CSV' do
      errors = Partner.import_csv([], organization.id)
      expect(errors).to be_empty
    end

    it 'handles case when organization is not found' do
      allow(Organization).to receive(:find).and_raise(ActiveRecord::RecordNotFound)
      expect { Partner.import_csv(csv, organization.id) }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
describe '#display_status' do
  let(:partner_awaiting_review) { build(:partner, status: :awaiting_review) }
  let(:partner_uninvited) { build(:partner, status: :uninvited) }
  let(:partner_approved) { build(:partner, status: :approved) }
  let(:partner_deactivated) { build(:partner, status: :deactivated) }

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
      expect(partner_deactivated.display_status).to eq('Deactivated')
    end
  end
end
end
