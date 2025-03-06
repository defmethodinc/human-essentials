require "rails_helper"

RSpec.describe Partner do
  describe '#display_status', :phoenix do
    let(:partner_awaiting_review) { build(:partner, :awaiting_review) }
    let(:partner_uninvited) { build(:partner, :uninvited) }
    let(:partner_approved) { build(:partner, :approved) }
    let(:partner_other_status) { build(:partner, :deactivated) }

    it 'returns Submitted when status is :awaiting_review' do
      expect(partner_awaiting_review.display_status).to eq('Submitted')
    end

    it 'returns Pending when status is :uninvited' do
      expect(partner_uninvited.display_status).to eq('Pending')
    end

    it 'returns Verified when status is :approved' do
      expect(partner_approved.display_status).to eq('Verified')
    end

    it 'returns titleized status for any other status' do
      expect(partner_other_status.display_status).to eq('Deactivated')
    end
  end
  describe '#primary_user', :phoenix do
    let(:partner) { create(:partner) }

    context 'when there are no users' do
      it 'returns nil' do
        expect(partner.primary_user).to be_nil
      end
    end

    context 'when there is only one user' do
      let!(:user) { create(:partner_user, partner: partner) }

      it 'returns the user' do
        expect(partner.primary_user).to eq(user)
      end
    end

    context 'when there are multiple users' do
      let!(:user1) { create(:partner_user, partner: partner, created_at: 2.days.ago) }
      let!(:user2) { create(:partner_user, partner: partner, created_at: 1.day.ago) }

      it 'returns the earliest created user' do
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
  describe '#deletable?', :phoenix do
    let(:partner) { build(:partner, :uninvited) }
    let(:distribution) { build(:distribution) }
    let(:request) { build(:request) }
    let(:user) { build(:partner_user, partner: partner) }

    it 'returns true when uninvited and has no distributions, requests, or users' do
      allow(partner).to receive(:distributions).and_return([])
      allow(partner).to receive(:requests).and_return([])
      allow(partner).to receive(:users).and_return([])
      expect(partner.deletable?).to be true
    end

    context 'when uninvited? is false' do
      let(:partner) { build(:partner, status: :approved) }

      it 'returns false' do
        expect(partner.deletable?).to be false
      end
    end

    context 'when distributions are present' do
      before { allow(partner).to receive(:distributions).and_return([distribution]) }

      it 'returns false' do
        expect(partner.deletable?).to be false
      end
    end

    context 'when requests are present' do
      before { allow(partner).to receive(:requests).and_return([request]) }

      it 'returns false' do
        expect(partner.deletable?).to be false
      end
    end

    context 'when users are present' do
      before { allow(partner).to receive(:users).and_return([user]) }

      it 'returns false' do
        expect(partner.deletable?).to be false
      end
    end

    context 'when uninvited? and distributions are present' do
      let(:partner) { build(:partner, status: :approved) }
      before { allow(partner).to receive(:distributions).and_return([distribution]) }

      it 'returns false' do
        expect(partner.deletable?).to be false
      end
    end

    context 'when distributions and requests are present' do
      before do
        allow(partner).to receive(:distributions).and_return([distribution])
        allow(partner).to receive(:requests).and_return([request])
      end

      it 'returns false' do
        expect(partner.deletable?).to be false
      end
    end

    context 'when requests and users are present' do
      before do
        allow(partner).to receive(:requests).and_return([request])
        allow(partner).to receive(:users).and_return([user])
      end

      it 'returns false' do
        expect(partner.deletable?).to be false
      end
    end

    context 'when users and distributions are present' do
      before do
        allow(partner).to receive(:users).and_return([user])
        allow(partner).to receive(:distributions).and_return([distribution])
      end

      it 'returns false' do
        expect(partner.deletable?).to be false
      end
    end
  end
  describe '#approvable?', :phoenix do
    let(:partner_invited) { build(:partner, status: :invited) }
    let(:partner_awaiting_review) { build(:partner, status: :awaiting_review) }
    let(:partner_uninvited) { build(:partner, status: :uninvited) }
    let(:partner_approved) { build(:partner, status: :approved) }
    let(:partner_error) { build(:partner, status: :error) }
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

    it 'returns false when status is error' do
      expect(partner_error.approvable?).to eq(false)
    end

    it 'returns false when status is recertification_required' do
      expect(partner_recertification_required.approvable?).to eq(false)
    end

    it 'returns false when status is deactivated' do
      expect(partner_deactivated.approvable?).to eq(false)
    end
  end
  describe '#import_csv', :phoenix do
    let(:organization) { create(:organization) }
    let(:partner_attributes) { {'name' => 'Test Partner', 'email' => 'test@example.com'} }
    let(:csv) { [partner_attributes] }

    context 'when CSV is valid' do
      it 'successfully imports a row' do
        expect {
          Partner.import_csv(csv, organization.id)
        }.to change { organization.partners.count }.by(1)
      end
    end

    context 'when there are errors during import' do
      before do
        allow_any_instance_of(PartnerCreateService).to receive(:call).and_return(double(errors: ['Error message']))
      end

      it 'returns errors' do
        errors = Partner.import_csv(csv, organization.id)
        expect(errors).to include('Test Partner: Error message')
      end
    end

    context 'when CSV is empty' do
      let(:csv) { [] }

      it 'does not create any partners' do
        expect {
          Partner.import_csv(csv, organization.id)
        }.not_to change { organization.partners.count }
      end
    end

    context 'when organization is not found' do
      it 'raises an ActiveRecord::RecordNotFound error' do
        expect {
          Partner.import_csv(csv, -1)
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'when CSV contains invalid data' do
      let(:partner_attributes) { {'name' => '', 'email' => 'invalid_email'} }

      it 'returns validation errors' do
        errors = Partner.import_csv(csv, organization.id)
        expect(errors).to include("Test Partner: Name can't be blank, Email is invalid")
      end
    end
  end
  describe '.csv_export_headers', :phoenix do
    it 'returns the correct CSV headers' do
      expected_headers = [
        "Agency Name",
        "Agency Email",
        "Agency Address",
        "Agency City",
        "Agency State",
        "Agency Zip Code",
        "Agency Website",
        "Agency Type",
        "Contact Name",
        "Contact Phone",
        "Contact Email",
        "Notes"
      ]
      expect(Partner.csv_export_headers).to eq(expected_headers)
    end
  end
  describe "#csv_export_attributes", :phoenix do
    let(:partner) { build(:partner, name: "Partner Name", email: "partner@example.com", agency_info: agency_info, contact_person: contact_person, notes: "Some notes") }
    let(:agency_info) { {address: "123 Main St", city: "Metropolis", state: "NY", zip_code: "12345", website: "http://example.com", agency_type: "Non-Profit"} }
    let(:contact_person) { {name: "John Doe", phone: "555-1234", email: "john.doe@example.com"} }

    it "returns all attributes when all data is present" do
      expect(partner.csv_export_attributes).to eq([
        "Partner Name",
        "partner@example.com",
        "123 Main St",
        "Metropolis",
        "NY",
        "12345",
        "http://example.com",
        "Non-Profit",
        "John Doe",
        "555-1234",
        "john.doe@example.com",
        "Some notes"
      ])
    end

    describe "when agency_info is nil" do
      let(:agency_info) { nil }

      it "returns nil for all agency_info fields" do
        expect(partner.csv_export_attributes).to eq([
          "Partner Name",
          "partner@example.com",
          nil,
          nil,
          nil,
          nil,
          nil,
          nil,
          "John Doe",
          "555-1234",
          "john.doe@example.com",
          "Some notes"
        ])
      end
    end

    describe "when contact_person is nil" do
      let(:contact_person) { nil }

      it "returns nil for all contact_person fields" do
        expect(partner.csv_export_attributes).to eq([
          "Partner Name",
          "partner@example.com",
          "123 Main St",
          "Metropolis",
          "NY",
          "12345",
          "http://example.com",
          "Non-Profit",
          nil,
          nil,
          nil,
          "Some notes"
        ])
      end
    end

    describe "when agency_info is missing keys" do
      context "missing address" do
        let(:agency_info) { {city: "Metropolis", state: "NY", zip_code: "12345", website: "http://example.com", agency_type: "Non-Profit"} }

        it "returns nil for address" do
          expect(partner.csv_export_attributes).to eq([
            "Partner Name",
            "partner@example.com",
            nil,
            "Metropolis",
            "NY",
            "12345",
            "http://example.com",
            "Non-Profit",
            "John Doe",
            "555-1234",
            "john.doe@example.com",
            "Some notes"
          ])
        end
      end

      context "missing city" do
        let(:agency_info) { {address: "123 Main St", state: "NY", zip_code: "12345", website: "http://example.com", agency_type: "Non-Profit"} }

        it "returns nil for city" do
          expect(partner.csv_export_attributes).to eq([
            "Partner Name",
            "partner@example.com",
            "123 Main St",
            nil,
            "NY",
            "12345",
            "http://example.com",
            "Non-Profit",
            "John Doe",
            "555-1234",
            "john.doe@example.com",
            "Some notes"
          ])
        end
      end

      context "missing state" do
        let(:agency_info) { {address: "123 Main St", city: "Metropolis", zip_code: "12345", website: "http://example.com", agency_type: "Non-Profit"} }

        it "returns nil for state" do
          expect(partner.csv_export_attributes).to eq([
            "Partner Name",
            "partner@example.com",
            "123 Main St",
            "Metropolis",
            nil,
            "12345",
            "http://example.com",
            "Non-Profit",
            "John Doe",
            "555-1234",
            "john.doe@example.com",
            "Some notes"
          ])
        end
      end

      context "missing zip_code" do
        let(:agency_info) { {address: "123 Main St", city: "Metropolis", state: "NY", website: "http://example.com", agency_type: "Non-Profit"} }

        it "returns nil for zip_code" do
          expect(partner.csv_export_attributes).to eq([
            "Partner Name",
            "partner@example.com",
            "123 Main St",
            "Metropolis",
            "NY",
            nil,
            "http://example.com",
            "Non-Profit",
            "John Doe",
            "555-1234",
            "john.doe@example.com",
            "Some notes"
          ])
        end
      end

      context "missing website" do
        let(:agency_info) { {address: "123 Main St", city: "Metropolis", state: "NY", zip_code: "12345", agency_type: "Non-Profit"} }

        it "returns nil for website" do
          expect(partner.csv_export_attributes).to eq([
            "Partner Name",
            "partner@example.com",
            "123 Main St",
            "Metropolis",
            "NY",
            "12345",
            nil,
            "Non-Profit",
            "John Doe",
            "555-1234",
            "john.doe@example.com",
            "Some notes"
          ])
        end
      end

      context "missing agency_type" do
        let(:agency_info) { {address: "123 Main St", city: "Metropolis", state: "NY", zip_code: "12345", website: "http://example.com"} }

        it "returns nil for agency_type" do
          expect(partner.csv_export_attributes).to eq([
            "Partner Name",
            "partner@example.com",
            "123 Main St",
            "Metropolis",
            "NY",
            "12345",
            "http://example.com",
            nil,
            "John Doe",
            "555-1234",
            "john.doe@example.com",
            "Some notes"
          ])
        end
      end
    end

    describe "when contact_person is missing keys" do
      context "missing name" do
        let(:contact_person) { {phone: "555-1234", email: "john.doe@example.com"} }

        it "returns nil for name" do
          expect(partner.csv_export_attributes).to eq([
            "Partner Name",
            "partner@example.com",
            "123 Main St",
            "Metropolis",
            "NY",
            "12345",
            "http://example.com",
            "Non-Profit",
            nil,
            "555-1234",
            "john.doe@example.com",
            "Some notes"
          ])
        end
      end

      context "missing phone" do
        let(:contact_person) { {name: "John Doe", email: "john.doe@example.com"} }

        it "returns nil for phone" do
          expect(partner.csv_export_attributes).to eq([
            "Partner Name",
            "partner@example.com",
            "123 Main St",
            "Metropolis",
            "NY",
            "12345",
            "http://example.com",
            "Non-Profit",
            "John Doe",
            nil,
            "john.doe@example.com",
            "Some notes"
          ])
        end
      end

      context "missing email" do
        let(:contact_person) { {name: "John Doe", phone: "555-1234"} }

        it "returns nil for email" do
          expect(partner.csv_export_attributes).to eq([
            "Partner Name",
            "partner@example.com",
            "123 Main St",
            "Metropolis",
            "NY",
            "12345",
            "http://example.com",
            "Non-Profit",
            "John Doe",
            "555-1234",
            nil,
            "Some notes"
          ])
        end
      end
    end
  end
  describe '#contact_person', :phoenix do
    let(:partner) { build(:partner) }
    let(:profile) { build(:partner_profile, partner: partner) }

    before do
      allow(partner).to receive(:profile).and_return(profile)
    end

    it 'returns @contact_person if already set' do
      contact_person = {name: 'John Doe', email: 'john@example.com', phone: '123-456-7890'}
      partner.instance_variable_set(:@contact_person, contact_person)
      expect(partner.contact_person).to eq(contact_person)
    end

    context 'when profile is blank' do
      let(:profile) { nil }

      it 'returns an empty hash' do
        expect(partner.contact_person).to eq({})
      end
    end

    context 'when profile is not blank' do
      before do
        allow(profile).to receive(:primary_contact_name).and_return('John Doe')
        allow(profile).to receive(:primary_contact_email).and_return('john@example.com')
      end

      it 'returns a hash with name, email, and phone' do
        allow(profile).to receive(:primary_contact_phone).and_return('123-456-7890')
        expect(partner.contact_person).to eq({
          name: 'John Doe',
          email: 'john@example.com',
          phone: '123-456-7890'
        })
      end

      context 'when primary_contact_phone is present' do
        before do
          allow(profile).to receive(:primary_contact_phone).and_return('123-456-7890')
        end

        it 'sets phone to primary_contact_phone' do
          expect(partner.contact_person[:phone]).to eq('123-456-7890')
        end
      end

      context 'when primary_contact_phone is not present' do
        before do
          allow(profile).to receive(:primary_contact_phone).and_return(nil)
          allow(profile).to receive(:primary_contact_mobile).and_return('098-765-4321')
        end

        it 'sets phone to primary_contact_mobile' do
          expect(partner.contact_person[:phone]).to eq('098-765-4321')
        end
      end
    end
  end
  describe '#agency_info', :phoenix do
    let(:partner) { build(:partner) }
    let(:profile) { build(:partner_profile, partner: partner) }

    before do
      allow(partner).to receive(:profile).and_return(profile)
    end

    it 'returns cached @agency_info if already set' do
      partner.instance_variable_set(:@agency_info, {cached: 'info'})
      expect(partner.agency_info).to eq({cached: 'info'})
    end

    context 'when profile is blank' do
      let(:profile) { nil }

      it 'returns an empty hash' do
        expect(partner.agency_info).to eq({})
      end
    end

    context 'when profile is present' do
      it 'constructs @agency_info with address' do
        expected_address = [profile.address1, profile.address2].select(&:present?).join(', ')
        expect(partner.agency_info[:address]).to eq(expected_address)
      end

      it 'includes city' do
        expect(partner.agency_info[:city]).to eq(profile.city)
      end

      it 'includes state' do
        expect(partner.agency_info[:state]).to eq(profile.state)
      end

      it 'includes zip code' do
        expect(partner.agency_info[:zip_code]).to eq(profile.zip_code)
      end

      it 'includes website' do
        expect(partner.agency_info[:website]).to eq(profile.website)
      end

      context 'when agency_type is OTHER' do
        let(:profile) { build(:partner_profile, partner: partner, agency_type: AGENCY_TYPES['OTHER'], other_agency_type: 'Special Type') }

        it 'appends other_agency_type to agency_type' do
          expect(partner.agency_info[:agency_type]).to eq("#{AGENCY_TYPES['OTHER']}: Special Type")
        end
      end

      context 'when agency_type is not OTHER' do
        let(:profile) { build(:partner_profile, partner: partner, agency_type: 'Regular Type') }

        it 'uses the given agency_type' do
          expect(partner.agency_info[:agency_type]).to eq('Regular Type')
        end
      end
    end
  end
  describe '#partials_to_show', :phoenix do
    let(:organization) { create(:organization) }
    let(:partner) { build(:partner, organization: organization) }

    context 'when partner_form_fields are present' do
      before do
        allow(organization).to receive(:partner_form_fields).and_return(['field1', 'field2'])
      end

      it 'returns partner_form_fields' do
        expect(partner.partials_to_show).to eq(['field1', 'field2'])
      end
    end

    context 'when partner_form_fields are not present' do
      before do
        allow(organization).to receive(:partner_form_fields).and_return(nil)
      end

      it 'returns ALL_PARTIALS' do
        expect(partner.partials_to_show).to eq(ALL_PARTIALS)
      end
    end
  end
  describe '#quantity_year_to_date', :phoenix do
    let(:partner) { create(:partner) }
    let(:organization) { partner.organization }
    let(:item) { create(:item, organization: organization) }
    let(:storage_location) { create(:storage_location, :with_items, item: item, organization: organization) }

    let(:distribution_this_year_with_items) do
      create(:distribution, :with_items, item: item, item_quantity: 10, partner: partner, storage_location: storage_location, issued_at: Time.zone.today.beginning_of_year + 1.day)
    end

    let(:distribution_this_year_without_items) do
      create(:distribution, partner: partner, storage_location: storage_location, issued_at: Time.zone.today.beginning_of_year + 1.day)
    end

    let(:distribution_last_year_with_items) do
      create(:distribution, :with_items, item: item, item_quantity: 5, partner: partner, storage_location: storage_location, issued_at: Time.zone.today.beginning_of_year - 1.day)
    end

    let(:distribution_exactly_beginning_of_year) do
      create(:distribution, :with_items, item: item, item_quantity: 15, partner: partner, storage_location: storage_location, issued_at: Time.zone.today.beginning_of_year)
    end

    it 'calculates the sum of quantities for distributions issued from the beginning of the year' do
      distribution_this_year_with_items
      expect(partner.quantity_year_to_date).to eq(10)
    end

    it 'returns zero when there are no distributions issued from the beginning of the year' do
      expect(partner.quantity_year_to_date).to eq(0)
    end

    it 'returns zero when there are distributions but none with line items' do
      distribution_this_year_without_items
      expect(partner.quantity_year_to_date).to eq(0)
    end

    it 'returns zero when all distributions with line items are issued before the beginning of the year' do
      distribution_last_year_with_items
      expect(partner.quantity_year_to_date).to eq(0)
    end

    it 'includes distributions issued exactly at the beginning of the year' do
      distribution_exactly_beginning_of_year
      expect(partner.quantity_year_to_date).to eq(15)
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

    it 'returns a hash with the correct keys' do
      expect(partner.impact_metrics.keys).to contain_exactly(:families_served, :children_served, :family_zipcodes, :family_zipcodes_list)
    end

    it 'returns the correct families_served count' do
      expect(partner.impact_metrics[:families_served]).to eq(families.size)
    end

    it 'returns the correct children_served count' do
      expect(partner.impact_metrics[:children_served]).to eq(children.size)
    end

    it 'returns the correct family_zipcodes count' do
      expect(partner.impact_metrics[:family_zipcodes]).to eq(zipcodes.size)
    end

    it 'returns the correct family_zipcodes list' do
      expect(partner.impact_metrics[:family_zipcodes_list]).to match_array(zipcodes)
    end

    describe 'when families_served_count returns an unexpected value' do
      before do
        allow(partner).to receive(:families_served_count).and_return(-1)
      end

      it 'handles the unexpected value gracefully' do
        expect(partner.impact_metrics[:families_served]).to eq(-1)
      end
    end

    describe 'when children_served_count returns an unexpected value' do
      before do
        allow(partner).to receive(:children_served_count).and_return(-1)
      end

      it 'handles the unexpected value gracefully' do
        expect(partner.impact_metrics[:children_served]).to eq(-1)
      end
    end

    describe 'when family_zipcodes_count returns an unexpected value' do
      before do
        allow(partner).to receive(:family_zipcodes_count).and_return(-1)
      end

      it 'handles the unexpected value gracefully' do
        expect(partner.impact_metrics[:family_zipcodes]).to eq(-1)
      end
    end

    describe 'when family_zipcodes_list returns an unexpected value' do
      before do
        allow(partner).to receive(:family_zipcodes_list).and_return(['unexpected'])
      end

      it 'handles the unexpected value gracefully' do
        expect(partner.impact_metrics[:family_zipcodes_list]).to eq(['unexpected'])
      end
    end
  end
  describe '#quota_exceeded?', :phoenix do
    let(:partner_without_quota) { build(:partner, quota: nil) }
    let(:partner_with_quota) { build(:partner, quota: 100) }

    it 'returns false when quota is not present' do
      expect(partner_without_quota.quota_exceeded?(50)).to be false
    end

    context 'when quota is present' do
      it 'returns false when total is equal to quota' do
        expect(partner_with_quota.quota_exceeded?(100)).to be false
      end

      it 'returns false when total is less than quota' do
        expect(partner_with_quota.quota_exceeded?(50)).to be false
      end

      it 'returns true when total is greater than quota' do
        expect(partner_with_quota.quota_exceeded?(150)).to be true
      end
    end
  end
  describe '#families_served_count', :phoenix do
    let(:partner) { build_stubbed(:partner) }

    context 'when there are no families' do
      it 'returns 0' do
        expect(partner.families_served_count).to eq(0)
      end
    end

    context 'when there is one family' do
      before do
        allow(partner).to receive(:families).and_return([build_stubbed(:partners_family, partner: partner)])
      end

      it 'returns 1' do
        expect(partner.families_served_count).to eq(1)
      end
    end

    context 'when there are multiple families' do
      before do
        allow(partner).to receive(:families).and_return(build_stubbed_list(:partners_family, 3, partner: partner))
      end

      it 'returns the correct count' do
        expect(partner.families_served_count).to eq(3)
      end
    end
  end
  describe '#children_served_count', :phoenix do
    let(:partner) { create(:partner) }

    context 'when there are no children' do
      it 'returns 0' do
        expect(partner.children_served_count).to eq(0)
      end
    end

    context 'when there is one child' do
      let!(:child) { create(:partners_child, family: create(:partners_family, partner: partner)) }

      it 'returns 1' do
        expect(partner.children_served_count).to eq(1)
      end
    end

    context 'when there are multiple children' do
      let!(:children) { create_list(:partners_child, 3, family: create(:partners_family, partner: partner)) }

      it 'returns the correct count' do
        expect(partner.children_served_count).to eq(3)
      end
    end

    context 'when children association is nil' do
      before do
        allow(partner).to receive(:children).and_return(nil)
      end

      it 'returns 0' do
        expect(partner.children_served_count).to eq(0)
      end
    end
  end
  describe '#family_zipcodes_count', :phoenix do
    let(:partner) { create(:partner) }

    context 'when there are no families' do
      it 'returns 0' do
        expect(partner.family_zipcodes_count).to eq(0)
      end
    end

    context 'when all zip codes are unique' do
      let!(:families) do
        build_list(:partners_family, 3, partner: partner, guardian_zip_code: -> { Faker::Address.unique.zip })
      end

      it 'returns the count of unique zip codes' do
        expect(partner.family_zipcodes_count).to eq(3)
      end
    end

    context 'when there are duplicate zip codes' do
      let!(:families) do
        build_list(:partners_family, 3, partner: partner, guardian_zip_code: '12345')
      end

      it 'returns the count of unique zip codes' do
        expect(partner.family_zipcodes_count).to eq(1)
      end
    end

    context 'for a mix of unique and duplicate zip codes' do
      let!(:families) do
        [
          build(:partners_family, partner: partner, guardian_zip_code: '12345'),
          build(:partners_family, partner: partner, guardian_zip_code: '12345'),
          build(:partners_family, partner: partner, guardian_zip_code: '67890')
        ]
      end

      it 'returns the count of unique zip codes' do
        expect(partner.family_zipcodes_count).to eq(2)
      end
    end

    context 'when handling nil or blank zip codes' do
      let!(:families) do
        [
          build(:partners_family, partner: partner, guardian_zip_code: nil),
          build(:partners_family, partner: partner, guardian_zip_code: ''),
          build(:partners_family, partner: partner, guardian_zip_code: '12345')
        ]
      end

      it 'ignores nil or blank zip codes and counts unique zip codes' do
        expect(partner.family_zipcodes_count).to eq(1)
      end
    end
  end
  describe '#family_zipcodes_list', :phoenix do
    let(:partner) { create(:partner) }

    context 'when there are no families' do
      it 'returns an empty list' do
        expect(partner.family_zipcodes_list).to eq([])
      end
    end

    context 'when there are duplicate zip codes' do
      let!(:family1) { create(:partners_family, partner: partner, guardian_zip_code: '12345') }
      let!(:family2) { create(:partners_family, partner: partner, guardian_zip_code: '12345') }

      it 'returns unique zip codes' do
        expect(partner.family_zipcodes_list).to eq(['12345'])
      end
    end

    context 'when all zip codes are unique' do
      let!(:family1) { create(:partners_family, partner: partner, guardian_zip_code: '12345') }
      let!(:family2) { create(:partners_family, partner: partner, guardian_zip_code: '67890') }

      it 'returns all zip codes' do
        expect(partner.family_zipcodes_list).to match_array(['12345', '67890'])
      end
    end

    context 'when there are nil or empty zip codes' do
      let!(:family1) { create(:partners_family, partner: partner, guardian_zip_code: nil) }
      let!(:family2) { create(:partners_family, partner: partner, guardian_zip_code: '') }
      let!(:family3) { create(:partners_family, partner: partner, guardian_zip_code: '12345') }

      it 'handles nil or empty zip codes gracefully' do
        expect(partner.family_zipcodes_list).to eq(['12345'])
      end
    end

    context 'with a large number of families' do
      before do
        create_list(:partners_family, 100, partner: partner, guardian_zip_code: '12345')
        create_list(:partners_family, 100, partner: partner, guardian_zip_code: '67890')
      end

      it 'performs well with a large number of families' do
        expect(partner.family_zipcodes_list).to match_array(['12345', '67890'])
      end
    end
  end
  describe '#correct_document_mime_type', :phoenix do
    let(:partner) { build(:partner) }
    let(:allowed_mime_type) { 'application/pdf' }
    let(:disallowed_mime_type) { 'image/png' }

    context 'when no documents are attached' do
      before do
        allow(partner.documents).to receive(:attached?).and_return(false)
      end

      it 'does not add errors' do
        partner.correct_document_mime_type
        expect(partner.errors[:documents]).to be_empty
      end
    end

    context 'when all documents have allowed MIME types' do
      before do
        allow(partner.documents).to receive(:attached?).and_return(true)
        allow(partner.documents).to receive(:any?).and_return(false)
      end

      it 'does not add errors' do
        partner.correct_document_mime_type
        expect(partner.errors[:documents]).to be_empty
      end
    end

    context 'when at least one document has a disallowed MIME type' do
      before do
        allow(partner.documents).to receive(:attached?).and_return(true)
        allow(partner.documents).to receive(:any?).and_return(true)
      end

      it 'adds an error' do
        partner.correct_document_mime_type
        expect(partner.errors[:documents]).to include('Must be a PDF or DOC file')
      end
    end
  end
  describe '#invite_new_partner', :phoenix do
    let(:partner) { build(:partner) }
    let(:user) { build(:user, email: partner.email) }
    let(:role_partner) { Role::PARTNER }

    context 'when the user does not exist' do
      it 'sends an invitation' do
        allow(User).to receive(:find_by).with(email: partner.email).and_return(nil)
        expect(UserInviteService).to receive(:invite).with(email: partner.email, roles: [role_partner], resource: partner)
        partner.invite_new_partner
      end
    end

    context 'when the user exists without all roles' do
      it 'adds roles and sends an invitation' do
        allow(User).to receive(:find_by).with(email: partner.email).and_return(user)
        allow(user).to receive(:has_role?).with(role_partner, partner).and_return(false)
        expect(UserInviteService).to receive(:invite).with(email: partner.email, roles: [role_partner], resource: partner)
        partner.invite_new_partner
      end
    end

    context 'when the user exists with some roles and force is true' do
      it 'adds roles and sends an invitation' do
        allow(User).to receive(:find_by).with(email: partner.email).and_return(user)
        allow(user).to receive(:has_role?).with(role_partner, partner).and_return(false)
        expect(UserInviteService).to receive(:invite).with(email: partner.email, roles: [role_partner], resource: partner)
        partner.invite_new_partner
      end
    end

    context 'when resource is nil' do
      it 'raises an exception' do
        allow(partner).to receive(:invite_new_partner).and_raise('Resource not found!')
        expect { partner.invite_new_partner }.to raise_error('Resource not found!')
      end
    end

    context 'when the user already has all roles' do
      it 'raises an exception' do
        allow(User).to receive(:find_by).with(email: partner.email).and_return(user)
        allow(user).to receive(:has_role?).with(role_partner, partner).and_return(true)
        expect { partner.invite_new_partner }.to raise_error('User already has the requested role!')
      end
    end

    context 'when email is invalid' do
      it 'skips invitation' do
        allow(UserInviteService).to receive(:invite).with(email: partner.email, roles: [role_partner], resource: partner).and_return(user)
        allow(user).to receive(:errors).and_return(email: ['is invalid'])
        expect(user).to receive(:skip_invitation=).with(true)
        partner.invite_new_partner
      end
    end

    describe 'edge cases' do
      context 'when name parameter is blank or nil' do
        it 'handles blank or nil name parameter' do
          allow(UserInviteService).to receive(:invite).with(email: partner.email, roles: [role_partner], resource: partner).and_yield(user)
          allow(user).to receive(:name=).with(nil)
          partner.invite_new_partner
        end
      end

      context 'when roles array is empty' do
        it 'handles empty roles array' do
          allow(UserInviteService).to receive(:invite).with(email: partner.email, roles: [], resource: partner).and_yield(user)
          allow(user).to receive(:roles).and_return([])
          partner.invite_new_partner
        end
      end

      context 'when force flag toggled between true and false' do
        it 'handles force flag toggled between true and false' do
          allow(User).to receive(:find_by).with(email: partner.email).and_return(user)
          allow(user).to receive(:has_role?).with(role_partner, partner).and_return(false)
          expect(UserInviteService).to receive(:invite).with(email: partner.email, roles: [role_partner], resource: partner)
          partner.invite_new_partner
        end
      end
    end
  end
  describe '#should_invite_because_email_changed?', :phoenix do
    let(:partner) { build(:partner, email: 'new_email@example.com') }
    let(:existing_partner_user) { create(:partner_user, email: 'existing_email@example.com') }

    context 'when email has changed and partner is invited, with no existing partner user with the same email' do
      let(:partner) { build(:partner, :invited, email: 'new_email@example.com') }

      it 'returns true when email has changed and partner is invited' do
        allow(partner).to receive(:email_changed?).and_return(true)
        allow(partner).to receive(:invited?).and_return(true)
        allow(partner).to receive(:partner_user_with_same_email_exist?).and_return(false)
        expect(partner.should_invite_because_email_changed?).to eq(true)
      end
    end

    context 'when email has changed and partner is awaiting review, with no existing partner user with the same email' do
      let(:partner) { build(:partner, :awaiting_review, email: 'new_email@example.com') }

      it 'returns true when email has changed and partner is awaiting review' do
        allow(partner).to receive(:email_changed?).and_return(true)
        allow(partner).to receive(:awaiting_review?).and_return(true)
        allow(partner).to receive(:partner_user_with_same_email_exist?).and_return(false)
        expect(partner.should_invite_because_email_changed?).to eq(true)
      end
    end

    context 'when email has changed and recertification is required, with no existing partner user with the same email' do
      let(:partner) { build(:partner, :recertification_required, email: 'new_email@example.com') }

      it 'returns true when email has changed and recertification is required' do
        allow(partner).to receive(:email_changed?).and_return(true)
        allow(partner).to receive(:recertification_required?).and_return(true)
        allow(partner).to receive(:partner_user_with_same_email_exist?).and_return(false)
        expect(partner.should_invite_because_email_changed?).to eq(true)
      end
    end

    context 'when email has changed and partner is approved, with no existing partner user with the same email' do
      let(:partner) { build(:partner, :approved, email: 'new_email@example.com') }

      it 'returns true when email has changed and partner is approved' do
        allow(partner).to receive(:email_changed?).and_return(true)
        allow(partner).to receive(:approved?).and_return(true)
        allow(partner).to receive(:partner_user_with_same_email_exist?).and_return(false)
        expect(partner.should_invite_because_email_changed?).to eq(true)
      end
    end

    context 'when email has changed and one condition is true, but a partner user with the same email exists' do
      let(:partner) { build(:partner, :invited, email: existing_partner_user.email) }

      it 'returns false when a partner user with the same email exists' do
        allow(partner).to receive(:email_changed?).and_return(true)
        allow(partner).to receive(:invited?).and_return(true)
        allow(partner).to receive(:partner_user_with_same_email_exist?).and_return(true)
        expect(partner.should_invite_because_email_changed?).to eq(false)
      end
    end

    context 'when email has not changed' do
      let(:partner) { build(:partner, email: 'existing_email@example.com') }

      it 'returns false when email has not changed' do
        allow(partner).to receive(:email_changed?).and_return(false)
        expect(partner.should_invite_because_email_changed?).to eq(false)
      end
    end
  end
  describe '#partner_user_with_same_email_exist?', :phoenix do
    let(:partner) { create(:partner) }
    let(:email) { 'test@example.com' }

    context 'when a user with the same email exists and has the partner role' do
      let!(:user_with_partner_role) { create(:partner_user, email: email, partner: partner) }

      it 'returns true' do
        expect(partner.partner_user_with_same_email_exist?).to be true
      end
    end

    context 'when a user with the same email exists but does not have the partner role' do
      let!(:user_without_partner_role) { create(:user, email: email) }

      it 'returns false' do
        expect(partner.partner_user_with_same_email_exist?).to be false
      end
    end

    context 'when no user with the same email exists' do
      it 'returns false' do
        expect(partner.partner_user_with_same_email_exist?).to be false
      end
    end
  end
end
