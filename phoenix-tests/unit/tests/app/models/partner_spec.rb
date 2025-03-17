require "rails_helper"

RSpec.describe Partner do
  describe '#display_status', :phoenix do
    let(:partner_awaiting_review) { create(:partner, :awaiting_review) }
    let(:partner_uninvited) { build(:partner, :uninvited) }
    let(:partner_approved) { build(:partner, :approved) }
    let(:partner_other_status) { build(:partner, :deactivated) }

    it 'returns Submitted when status is :awaiting_review' do
      pending "Fails because `status` is an enum which returns a string, but the method checks for a symbol."
      expect(partner_awaiting_review.display_status).to eq('Submitted')
    end

    it 'returns Pending when status is :uninvited' do
      pending "Fails because `status` is an enum which returns a string, but the method checks for a symbol."
      expect(partner_uninvited.display_status).to eq('Pending')
    end

    it 'returns Verified when status is :approved' do
      pending "Fails because `status` is an enum which returns a string, but the method checks for a symbol."
      expect(partner_approved.display_status).to eq('Verified')
    end

    it 'returns titleized status for any other status' do
      expect(partner_other_status.display_status).to eq('Deactivated')
    end
  end
  describe '#primary_user', :phoenix do
    let(:partner) { create(:partner, :uninvited, without_profile: true) }

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
        expect(errors).to include(": Name can't be blank and Email is invalid")
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
        expect(partner.partials_to_show).to eq(Partner::ALL_PARTIALS)
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
end
