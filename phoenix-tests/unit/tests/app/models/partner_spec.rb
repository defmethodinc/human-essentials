
require "rails_helper"

RSpec.describe Partner do
describe '#agency_info' do
  let(:partner) { create(:partner) }
  let(:profile) { partner.profile }

  it 'returns memoized @agency_info if already set' do
    partner.instance_variable_set(:@agency_info, { memoized: true })
    expect(partner.agency_info).to eq({ memoized: true })
  end

  describe 'when constructing address' do
    context 'with both address1 and address2' do
      let(:profile) { build(:partner_profile, address1: '123 Main St', address2: 'Apt 4B') }

      it 'joins address1 and address2 with a comma' do
        expect(partner.agency_info[:address]).to eq('123 Main St, Apt 4B')
      end
    end

    context 'with only address1' do
      let(:profile) { build(:partner_profile, address1: '123 Main St', address2: nil) }

      it 'returns address1 when address2 is missing' do
        expect(partner.agency_info[:address]).to eq('123 Main St')
      end
    end
  end

  describe 'when including profile details' do
    let(:profile) { build(:partner_profile, city: 'Metropolis', state: 'NY', zip_code: '12345', website: 'http://example.com') }

    it 'includes city from profile' do
      expect(partner.agency_info[:city]).to eq('Metropolis')
    end

    it 'includes state from profile' do
      expect(partner.agency_info[:state]).to eq('NY')
    end

    it 'includes zip_code from profile' do
      expect(partner.agency_info[:zip_code]).to eq('12345')
    end

    it 'includes website from profile' do
      expect(partner.agency_info[:website]).to eq('http://example.com')
    end
  end

  describe 'when handling agency_type' do
    context 'with a specific agency_type' do
      let(:profile) { build(:partner_profile, agency_type: 'government') }

      it 'translates agency_type using I18n' do
        expect(partner.agency_info[:agency_type]).to eq(I18n.t(:government, scope: :partners_profile))
      end
    end

    context 'with agency_type as :other' do
      let(:profile) { build(:partner_profile, agency_type: 'other', other_agency_type: 'Custom Type') }

      it 'appends other_agency_type if agency_type is :other' do
        expect(partner.agency_info[:agency_type]).to eq("#{I18n.t(:other, scope: :partners_profile)}: Custom Type")
      end
    end

    context 'with nil agency_type' do
      let(:profile) { build(:partner_profile, agency_type: nil) }

      it 'handles nil agency_type gracefully' do
        expect(partner.agency_info[:agency_type]).to be_nil
      end
    end
  end
end
describe '#display_status' do
  let(:partner_awaiting_review) { build(:partner, status: :awaiting_review) }
  let(:partner_uninvited) { build(:partner, status: :uninvited) }
  let(:partner_approved) { build(:partner, status: :approved) }
  let(:partner_deactivated) { build(:partner, status: :deactivated) } # Use a valid status for the 'other' case

  it 'returns "Submitted" when status is :awaiting_review' do
    expect(partner_awaiting_review.display_status).to eq('Submitted')
  end

  it 'returns "Pending" when status is :uninvited' do
    expect(partner_uninvited.display_status).to eq('Pending')
  end

  it 'returns "Verified" when status is :approved' do
    expect(partner_approved.display_status).to eq('Verified')
  end

  it 'returns titleized status for any other status' do
    expect(partner_deactivated.display_status).to eq('Deactivated')
  end
end
describe '#import_csv' do
  let(:organization) { create(:organization) }
  let(:valid_csv) { CSV.parse("name,email\nValid Partner,valid@example.com\n", headers: true) }
  let(:invalid_csv) { CSV.parse("name,email\nInvalid Partner,\n", headers: true) }
  let(:non_existent_organization_id) { -1 }

  it 'imports partners successfully when CSV is valid' do
    allow(Organization).to receive(:find).with(organization.id).and_return(organization)
    expect(Partner.import_csv(valid_csv, organization.id)).to eq([])
  end

  it 'returns errors when CSV has invalid data' do
    allow(Organization).to receive(:find).with(organization.id).and_return(organization)
    expect(Partner.import_csv(invalid_csv, organization.id)).to include("Invalid Partner: Email can't be blank")
  end

  describe 'when organization is not found' do
    it 'raises an error' do
      expect { Partner.import_csv(valid_csv, non_existent_organization_id) }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'when PartnerCreateService returns errors' do
    let(:partner_create_service) { instance_double('PartnerCreateService', call: nil, errors: ['Error'], partner: build(:partner, name: 'Error Partner')) }

    before do
      allow(PartnerCreateService).to receive(:new).and_return(partner_create_service)
    end

    it 'collects errors for each partner' do
      allow(Organization).to receive(:find).with(organization.id).and_return(organization)
      expect(Partner.import_csv(valid_csv, organization.id)).to include('Error Partner: Error')
    end
  end

  it 'returns an empty array when no errors are present' do
    allow(Organization).to receive(:find).with(organization.id).and_return(organization)
    allow_any_instance_of(PartnerCreateService).to receive(:errors).and_return([])
    expect(Partner.import_csv(valid_csv, organization.id)).to eq([])
  end
end
describe "#partials_to_show" do
  let(:organization) { create(:organization) }
  let(:partner) { build(:partner, organization: organization) }
  let(:partner_with_form_fields) { create(:partner, organization: organization) }
  let(:partner_without_form_fields) { create(:partner, organization: organization) }

  before do
    allow(partner_with_form_fields.organization).to receive(:partner_form_fields).and_return(['form_field_1', 'form_field_2'])
    allow(partner_without_form_fields.organization).to receive(:partner_form_fields).and_return(nil)
  end

  it "returns partner_form_fields when present" do
    expect(partner_with_form_fields.partials_to_show).to eq(['form_field_1', 'form_field_2'])
  end

  it "returns ALL_PARTIALS when partner_form_fields is not present" do
    expect(partner_without_form_fields.partials_to_show).to eq(Partner::ALL_PARTIALS)
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
      before { partner.users << user }

      it 'returns the only user' do
        expect(partner.primary_user).to eq(user)
      end
    end

    context 'when there are multiple users' do
      let!(:user1) { create(:user, created_at: 2.days.ago) }
      let!(:user2) { create(:user, created_at: 1.day.ago) }
      before { partner.users << [user1, user2] }

      it 'returns the first user' do
        expect(partner.primary_user).to eq(user1)
      end
    end

    context 'when users have the same creation date' do
      let!(:user1) { create(:user, created_at: 1.day.ago) }
      let!(:user2) { create(:user, created_at: 1.day.ago) }
      before { partner.users << [user1, user2] }

      it 'returns the first user in the list' do
        expect(partner.primary_user).to eq(user1)
      end
    end
  end
describe '#quantity_year_to_date' do
    let(:partner) { create(:partner) }
    let(:organization) { create(:organization) }
    let(:storage_location) { create(:storage_location, organization: organization) }
    let(:item) { create(:item) }

    let(:distribution_within_year) do
      create(:distribution, :with_items, partner: partner, organization: organization, storage_location: storage_location, issued_at: Time.zone.today.beginning_of_year + 1.day, item: item, item_quantity: 10)
    end

    let(:distribution_outside_year) do
      create(:distribution, :with_items, partner: partner, organization: organization, storage_location: storage_location, issued_at: Time.zone.today.beginning_of_year - 1.day, item: item, item_quantity: 10)
    end

    let(:distribution_no_line_items) do
      create(:distribution, partner: partner, organization: organization, storage_location: storage_location, issued_at: Time.zone.today.beginning_of_year + 1.day)
    end

    it 'calculates total quantity for distributions issued within the current year' do
      distribution_within_year
      expect(partner.quantity_year_to_date).to eq(10)
    end

    it 'returns zero when there are no distributions issued within the current year' do
      distribution_outside_year
      expect(partner.quantity_year_to_date).to eq(0)
    end

    describe 'when distributions exist but none have line items' do
      it 'returns zero' do
        distribution_no_line_items
        expect(partner.quantity_year_to_date).to eq(0)
      end
    end

    describe 'on boundary conditions' do
      it 'calculates correctly on the first day of the year' do
        distribution_within_year.update(issued_at: Time.zone.today.beginning_of_year)
        expect(partner.quantity_year_to_date).to eq(10)
      end

      it 'calculates correctly on the last day of the year' do
        distribution_within_year.update(issued_at: Time.zone.today.end_of_year)
        expect(partner.quantity_year_to_date).to eq(10)
      end
    end

    describe 'with multiple distributions and varying issued dates' do
      it 'sums quantities correctly' do
        distribution_within_year
        distribution_outside_year
        expect(partner.quantity_year_to_date).to eq(10)
      end
    end
  end
describe '#deletable?', :phoenix do
  let(:partner) { build(:partner, :uninvited) }
  let(:distributions) { [] }
  let(:requests) { [] }
  let(:users) { [] }

  before do
    allow(partner).to receive(:distributions).and_return(distributions)
    allow(partner).to receive(:requests).and_return(requests)
    allow(partner).to receive(:users).and_return(users)
  end

  it 'returns true when partner is uninvited and has no distributions, requests, or users' do
    expect(partner.deletable?).to be true
  end

  describe 'when partner is invited' do
    let(:partner) { build(:partner, status: :approved) }

    it 'returns false' do
      expect(partner.deletable?).to be false
    end
  end

  describe 'when there are distributions' do
    let(:distributions) { [double] }

    it 'returns false' do
      expect(partner.deletable?).to be false
    end
  end

  describe 'when there are requests' do
    let(:requests) { [double] }

    it 'returns false' do
      expect(partner.deletable?).to be false
    end
  end

  describe 'when there are users' do
    let(:users) { [double] }

    it 'returns false' do
      expect(partner.deletable?).to be false
    end
  end

  describe 'when multiple conditions are false' do
    context 'when partner is invited and has distributions' do
      let(:partner) { build(:partner, status: :approved) }
      let(:distributions) { [double] }

      it 'returns false' do
        expect(partner.deletable?).to be false
      end
    end

    context 'when partner is invited and has requests' do
      let(:partner) { build(:partner, status: :approved) }
      let(:requests) { [double] }

      it 'returns false' do
        expect(partner.deletable?).to be false
      end
    end

    context 'when partner is invited and has users' do
      let(:partner) { build(:partner, status: :approved) }
      let(:users) { [double] }

      it 'returns false' do
        expect(partner.deletable?).to be false
      end
    end

    context 'when there are distributions and requests' do
      let(:distributions) { [double] }
      let(:requests) { [double] }

      it 'returns false' do
        expect(partner.deletable?).to be false
      end
    end

    context 'when there are distributions and users' do
      let(:distributions) { [double] }
      let(:users) { [double] }

      it 'returns false' do
        expect(partner.deletable?).to be false
      end
    end

    context 'when there are requests and users' do
      let(:requests) { [double] }
      let(:users) { [double] }

      it 'returns false' do
        expect(partner.deletable?).to be false
      end
    end

    context 'when partner is invited, has distributions, and requests' do
      let(:partner) { build(:partner, status: :approved) }
      let(:distributions) { [double] }
      let(:requests) { [double] }

      it 'returns false' do
        expect(partner.deletable?).to be false
      end
    end

    context 'when partner is invited, has distributions, and users' do
      let(:partner) { build(:partner, status: :approved) }
      let(:distributions) { [double] }
      let(:users) { [double] }

      it 'returns false' do
        expect(partner.deletable?).to be false
      end
    end

    context 'when partner is invited, has requests, and users' do
      let(:partner) { build(:partner, status: :approved) }
      let(:requests) { [double] }
      let(:users) { [double] }

      it 'returns false' do
        expect(partner.deletable?).to be false
      end
    end

    context 'when there are distributions, requests, and users' do
      let(:distributions) { [double] }
      let(:requests) { [double] }
      let(:users) { [double] }

      it 'returns false' do
        expect(partner.deletable?).to be false
      end
    end

    context 'when all conditions are false' do
      let(:partner) { build(:partner, status: :approved) }
      let(:distributions) { [double] }
      let(:requests) { [double] }
      let(:users) { [double] }

      it 'returns false' do
        expect(partner.deletable?).to be false
      end
    end
  end
end
describe '#approvable?', :phoenix do
  let(:partner_invited) { build(:partner, status: :invited) }
  let(:partner_awaiting_review) { build(:partner, status: :awaiting_review) }
  let(:partner_uninvited) { build(:partner, status: :uninvited) }

  it 'returns true when partner is invited' do
    expect(partner_invited.approvable?).to eq(true)
  end

  it 'returns true when partner is awaiting review' do
    expect(partner_awaiting_review.approvable?).to eq(true)
  end

  it 'returns false when partner is neither invited nor awaiting review' do
    expect(partner_uninvited.approvable?).to eq(false)
  end
end
describe "#partials_to_show" do
  let(:organization) { create(:organization) }
  let(:partner) { build(:partner, organization: organization) }
  let(:partner_with_form_fields) { create(:partner, organization: organization) }
  let(:partner_without_form_fields) { create(:partner, organization: organization) }

  before do
    allow(partner_with_form_fields.organization).to receive(:partner_form_fields).and_return(['form_field_1', 'form_field_2'])
    allow(partner_without_form_fields.organization).to receive(:partner_form_fields).and_return(nil)
  end

  it "returns partner_form_fields when present" do
    expect(partner_with_form_fields.partials_to_show).to eq(['form_field_1', 'form_field_2'])
  end

  it "returns ALL_PARTIALS when partner_form_fields is not present" do
    expect(partner_without_form_fields.partials_to_show).to eq(Partner::ALL_PARTIALS)
  end
end
describe '#quantity_year_to_date' do
    let(:partner) { create(:partner) }
    let(:organization) { create(:organization) }
    let(:storage_location) { create(:storage_location, organization: organization) }
    let(:item) { create(:item) }

    let(:distribution_within_year) do
      create(:distribution, :with_items, partner: partner, organization: organization, storage_location: storage_location, issued_at: Time.zone.today.beginning_of_year + 1.day, item: item, item_quantity: 10)
    end

    let(:distribution_outside_year) do
      create(:distribution, :with_items, partner: partner, organization: organization, storage_location: storage_location, issued_at: Time.zone.today.beginning_of_year - 1.day, item: item, item_quantity: 10)
    end

    let(:distribution_no_line_items) do
      create(:distribution, partner: partner, organization: organization, storage_location: storage_location, issued_at: Time.zone.today.beginning_of_year + 1.day)
    end

    it 'calculates total quantity for distributions issued within the current year' do
      distribution_within_year
      expect(partner.quantity_year_to_date).to eq(10)
    end

    it 'returns zero when there are no distributions issued within the current year' do
      distribution_outside_year
      expect(partner.quantity_year_to_date).to eq(0)
    end

    describe 'when distributions exist but none have line items' do
      it 'returns zero' do
        distribution_no_line_items
        expect(partner.quantity_year_to_date).to eq(0)
      end
    end

    describe 'on boundary conditions' do
      it 'calculates correctly on the first day of the year' do
        distribution_within_year.update(issued_at: Time.zone.today.beginning_of_year)
        expect(partner.quantity_year_to_date).to eq(10)
      end

      it 'calculates correctly on the last day of the year' do
        distribution_within_year.update(issued_at: Time.zone.today.end_of_year)
        expect(partner.quantity_year_to_date).to eq(10)
      end
    end

    describe 'with multiple distributions and varying issued dates' do
      it 'sums quantities correctly' do
        distribution_within_year
        distribution_outside_year
        expect(partner.quantity_year_to_date).to eq(10)
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
      before { partner.users << user }

      it 'returns the only user' do
        expect(partner.primary_user).to eq(user)
      end
    end

    context 'when there are multiple users' do
      let!(:user1) { create(:user, created_at: 2.days.ago) }
      let!(:user2) { create(:user, created_at: 1.day.ago) }
      before { partner.users << [user1, user2] }

      it 'returns the first user' do
        expect(partner.primary_user).to eq(user1)
      end
    end

    context 'when users have the same creation date' do
      let!(:user1) { create(:user, created_at: 1.day.ago) }
      let!(:user2) { create(:user, created_at: 1.day.ago) }
      before { partner.users << [user1, user2] }

      it 'returns the first user in the list' do
        expect(partner.primary_user).to eq(user1)
      end
    end
  end
describe '#agency_info' do
  let(:partner) { create(:partner) }
  let(:profile) { partner.profile }

  it 'returns memoized @agency_info if already set' do
    partner.instance_variable_set(:@agency_info, { memoized: true })
    expect(partner.agency_info).to eq({ memoized: true })
  end

  describe 'when constructing address' do
    context 'with both address1 and address2' do
      let(:profile) { build(:partner_profile, address1: '123 Main St', address2: 'Apt 4B') }

      it 'joins address1 and address2 with a comma' do
        expect(partner.agency_info[:address]).to eq('123 Main St, Apt 4B')
      end
    end

    context 'with only address1' do
      let(:profile) { build(:partner_profile, address1: '123 Main St', address2: nil) }

      it 'returns address1 when address2 is missing' do
        expect(partner.agency_info[:address]).to eq('123 Main St')
      end
    end
  end

  describe 'when including profile details' do
    let(:profile) { build(:partner_profile, city: 'Metropolis', state: 'NY', zip_code: '12345', website: 'http://example.com') }

    it 'includes city from profile' do
      expect(partner.agency_info[:city]).to eq('Metropolis')
    end

    it 'includes state from profile' do
      expect(partner.agency_info[:state]).to eq('NY')
    end

    it 'includes zip_code from profile' do
      expect(partner.agency_info[:zip_code]).to eq('12345')
    end

    it 'includes website from profile' do
      expect(partner.agency_info[:website]).to eq('http://example.com')
    end
  end

  describe 'when handling agency_type' do
    context 'with a specific agency_type' do
      let(:profile) { build(:partner_profile, agency_type: 'government') }

      it 'translates agency_type using I18n' do
        expect(partner.agency_info[:agency_type]).to eq(I18n.t(:government, scope: :partners_profile))
      end
    end

    context 'with agency_type as :other' do
      let(:profile) { build(:partner_profile, agency_type: 'other', other_agency_type: 'Custom Type') }

      it 'appends other_agency_type if agency_type is :other' do
        expect(partner.agency_info[:agency_type]).to eq("#{I18n.t(:other, scope: :partners_profile)}: Custom Type")
      end
    end

    context 'with nil agency_type' do
      let(:profile) { build(:partner_profile, agency_type: nil) }

      it 'handles nil agency_type gracefully' do
        expect(partner.agency_info[:agency_type]).to be_nil
      end
    end
  end
end
describe '#display_status' do
  let(:partner_awaiting_review) { build(:partner, status: :awaiting_review) }
  let(:partner_uninvited) { build(:partner, status: :uninvited) }
  let(:partner_approved) { build(:partner, status: :approved) }
  let(:partner_deactivated) { build(:partner, status: :deactivated) } # Use a valid status for the 'other' case

  it 'returns "Submitted" when status is :awaiting_review' do
    expect(partner_awaiting_review.display_status).to eq('Submitted')
  end

  it 'returns "Pending" when status is :uninvited' do
    expect(partner_uninvited.display_status).to eq('Pending')
  end

  it 'returns "Verified" when status is :approved' do
    expect(partner_approved.display_status).to eq('Verified')
  end

  it 'returns titleized status for any other status' do
    expect(partner_deactivated.display_status).to eq('Deactivated')
  end
end
describe '#contact_person', :phoenix do
  let(:partner) { build(:partner) }
  let(:profile) { build(:partner_profile, partner: partner) }

  before do
    allow(partner).to receive(:profile).and_return(profile)
  end

  context 'when contact person is already set' do
    before do
      partner.instance_variable_set(:@contact_person, { name: 'Existing Name', email: 'existing@example.com', phone: '1234567890' })
    end

    it 'returns the existing contact person' do
      expect(partner.contact_person).to eq({ name: 'Existing Name', email: 'existing@example.com', phone: '1234567890' })
    end
  end

  context 'when initializing contact person' do
    before do
      allow(profile).to receive(:primary_contact_name).and_return('John Doe')
      allow(profile).to receive(:primary_contact_email).and_return('john@example.com')
    end

    it 'sets phone when primary contact phone is present' do
      allow(profile).to receive(:primary_contact_phone).and_return('1234567890')
      expect(partner.contact_person[:phone]).to eq('1234567890')
    end

    it 'sets phone to mobile when primary contact phone is absent' do
      allow(profile).to receive(:primary_contact_phone).and_return(nil)
      allow(profile).to receive(:primary_contact_mobile).and_return('0987654321')
      expect(partner.contact_person[:phone]).to eq('0987654321')
    end

    it 'sets phone to nil when both phone and mobile are absent' do
      allow(profile).to receive(:primary_contact_phone).and_return(nil)
      allow(profile).to receive(:primary_contact_mobile).and_return(nil)
      expect(partner.contact_person[:phone]).to be_nil
    end

    it 'sets name correctly' do
      expect(partner.contact_person[:name]).to eq('John Doe')
    end

    it 'sets email correctly' do
      expect(partner.contact_person[:email]).to eq('john@example.com')
    end

    it 'sets name to nil when name is absent' do
      allow(profile).to receive(:primary_contact_name).and_return(nil)
      expect(partner.contact_person[:name]).to be_nil
    end

    it 'sets email to nil when email is absent' do
      allow(profile).to receive(:primary_contact_email).and_return(nil)
      expect(partner.contact_person[:email]).to be_nil
    end
  end
end
describe '#import_csv' do
  let(:organization) { create(:organization) }
  let(:valid_csv) { CSV.parse("name,email\nValid Partner,valid@example.com\n", headers: true) }
  let(:invalid_csv) { CSV.parse("name,email\nInvalid Partner,\n", headers: true) }
  let(:non_existent_organization_id) { -1 }

  it 'imports partners successfully when CSV is valid' do
    allow(Organization).to receive(:find).with(organization.id).and_return(organization)
    expect(Partner.import_csv(valid_csv, organization.id)).to eq([])
  end

  it 'returns errors when CSV has invalid data' do
    allow(Organization).to receive(:find).with(organization.id).and_return(organization)
    expect(Partner.import_csv(invalid_csv, organization.id)).to include("Invalid Partner: Email can't be blank")
  end

  describe 'when organization is not found' do
    it 'raises an error' do
      expect { Partner.import_csv(valid_csv, non_existent_organization_id) }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'when PartnerCreateService returns errors' do
    let(:partner_create_service) { instance_double('PartnerCreateService', call: nil, errors: ['Error'], partner: build(:partner, name: 'Error Partner')) }

    before do
      allow(PartnerCreateService).to receive(:new).and_return(partner_create_service)
    end

    it 'collects errors for each partner' do
      allow(Organization).to receive(:find).with(organization.id).and_return(organization)
      expect(Partner.import_csv(valid_csv, organization.id)).to include('Error Partner: Error')
    end
  end

  it 'returns an empty array when no errors are present' do
    allow(Organization).to receive(:find).with(organization.id).and_return(organization)
    allow_any_instance_of(PartnerCreateService).to receive(:errors).and_return([])
    expect(Partner.import_csv(valid_csv, organization.id)).to eq([])
  end
end
describe "#impact_metrics", :phoenix do
  let(:partner) { build(:partner) }
  let(:family) { build(:partners_family, partner: partner) }
  let(:child) { build(:partners_child, family: family) }

  before do
    allow(partner).to receive(:families_served_count).and_return(5)
    allow(partner).to receive(:children_served_count).and_return(10)
    allow(partner).to receive(:family_zipcodes_count).and_return(3)
    allow(partner).to receive(:family_zipcodes_list).and_return(['12345', '67890', '54321'])
  end

  it "returns a hash with expected keys" do
    expect(partner.impact_metrics.keys).to contain_exactly(:families_served, :children_served, :family_zipcodes, :family_zipcodes_list)
  end

  describe "when all methods return expected values" do
    it "returns the correct metrics" do
      expect(partner.impact_metrics).to eq({
        families_served: 5,
        children_served: 10,
        family_zipcodes: 3,
        family_zipcodes_list: ['12345', '67890', '54321']
      })
    end
  end

  describe "when a method returns nil" do
    before do
      allow(partner).to receive(:families_served_count).and_return(nil)
    end

    it "handles nil values gracefully" do
      expect(partner.impact_metrics[:families_served]).to be_nil
    end
  end

  describe "when a method returns a negative number" do
    before do
      allow(partner).to receive(:children_served_count).and_return(-1)
    end

    it "handles negative values appropriately" do
      expect(partner.impact_metrics[:children_served]).to eq(-1)
    end
  end

  describe "when a method returns an empty list" do
    before do
      allow(partner).to receive(:family_zipcodes_list).and_return([])
    end

    it "handles empty lists correctly" do
      expect(partner.impact_metrics[:family_zipcodes_list]).to eq([])
    end
  end

  describe "when methods return edge case values" do
    it "handles maximum values" do
      allow(partner).to receive(:families_served_count).and_return(Float::INFINITY)
      expect(partner.impact_metrics[:families_served]).to eq(Float::INFINITY)
    end

    it "handles minimum values" do
      allow(partner).to receive(:families_served_count).and_return(-Float::INFINITY)
      expect(partner.impact_metrics[:families_served]).to eq(-Float::INFINITY)
    end
  end
end
describe "#quota_exceeded?", :phoenix do
  let(:partner_with_quota) { build(:partner, quota: 100) }
  let(:partner_without_quota) { build(:partner, quota: nil) }

  it "returns true when quota is present and total is greater than quota" do
    expect(partner_with_quota.quota_exceeded?(150)).to be true
  end

  it "returns false when quota is present and total is equal to quota" do
    expect(partner_with_quota.quota_exceeded?(100)).to be false
  end

  it "returns false when quota is present and total is less than quota" do
    expect(partner_with_quota.quota_exceeded?(50)).to be false
  end

  it "returns false when quota is not present" do
    expect(partner_without_quota.quota_exceeded?(150)).to be false
  end
end
end
