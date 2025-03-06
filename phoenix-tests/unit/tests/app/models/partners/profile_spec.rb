
require "rails_helper"

RSpec.describe Partners::Profile do
describe '#client_share_total', :phoenix do
  let(:partner_profile) { create(:partner_profile) }

  context 'when served_areas is empty' do
    it 'returns 0' do
      allow(partner_profile).to receive(:served_areas).and_return([])
      expect(partner_profile.client_share_total).to eq(0)
    end
  end

  context 'when all client_share values are nil' do
    let!(:served_areas) { build_list(:partners_served_area, 3, partner_profile: partner_profile, client_share: nil) }

    it 'returns 0' do
      allow(partner_profile).to receive(:served_areas).and_return(served_areas)
      expect(partner_profile.client_share_total).to eq(0)
    end
  end

  context 'when some client_share values are nil' do
    let!(:served_areas) { [build(:partners_served_area, partner_profile: partner_profile, client_share: nil), build(:partners_served_area, partner_profile: partner_profile, client_share: 5), build(:partners_served_area, partner_profile: partner_profile, client_share: 10)] }

    it 'sums non-nil client_share values' do
      allow(partner_profile).to receive(:served_areas).and_return(served_areas)
      expect(partner_profile.client_share_total).to eq(15)
    end
  end

  context 'when none of the client_share values are nil' do
    let!(:served_areas) { build_list(:partners_served_area, 3, partner_profile: partner_profile, client_share: 5) }

    it 'returns the sum of all client_share values' do
      allow(partner_profile).to receive(:served_areas).and_return(served_areas)
      expect(partner_profile.client_share_total).to eq(15)
    end
  end

  context 'when there is a single served_area with a non-nil client_share' do
    let!(:served_areas) { [build(:partners_served_area, partner_profile: partner_profile, client_share: 7)] }

    it 'returns the client_share value' do
      allow(partner_profile).to receive(:served_areas).and_return(served_areas)
      expect(partner_profile.client_share_total).to eq(7)
    end
  end
end
describe "#split_pick_up_emails", :phoenix do
  let(:profile) { build(:partner_profile, pick_up_email: pick_up_email) }

  context "when pick_up_email is nil" do
    let(:pick_up_email) { nil }

    it "returns nil" do
      expect(profile.split_pick_up_emails).to be_nil
    end
  end

  context "when emails are separated by commas" do
    let(:pick_up_email) { "email1@example.com,email2@example.com" }

    it "splits emails separated by commas" do
      expect(profile.split_pick_up_emails).to eq(["email1@example.com", "email2@example.com"])
    end
  end

  context "when emails are separated by spaces" do
    let(:pick_up_email) { "email1@example.com email2@example.com" }

    it "splits emails separated by spaces" do
      expect(profile.split_pick_up_emails).to eq(["email1@example.com", "email2@example.com"])
    end
  end

  context "when emails are separated by a mix of commas and spaces" do
    let(:pick_up_email) { "email1@example.com, email2@example.com email3@example.com" }

    it "splits emails separated by a mix of commas and spaces" do
      expect(profile.split_pick_up_emails).to eq(["email1@example.com", "email2@example.com", "email3@example.com"])
    end
  end

  context "when there are extra spaces or empty elements" do
    let(:pick_up_email) { "email1@example.com, , email2@example.com  " }

    it "removes extra spaces or empty elements" do
      expect(profile.split_pick_up_emails).to eq(["email1@example.com", "email2@example.com"])
    end
  end
end
describe '#check_social_media', :phoenix do
  let(:partner) { create(:partner, partials_to_show: ['media_information']) }
  let(:profile_with_website) { build(:partner_profile, website: 'http://example.com', partner: partner) }
  let(:profile_with_twitter) { build(:partner_profile, twitter: '@example', partner: partner) }
  let(:profile_with_facebook) { build(:partner_profile, facebook: 'facebook.com/example', partner: partner) }
  let(:profile_with_instagram) { build(:partner_profile, instagram: '@example', partner: partner) }
  let(:profile_without_media_info) { build(:partner_profile, partner: create(:partner, partials_to_show: [])) }
  let(:profile_no_social_media_checked) { build(:partner_profile, no_social_media_presence: true, partner: partner) }
  let(:profile_no_social_media_unchecked) { build(:partner_profile, no_social_media_presence: false, partner: partner) }

  it 'returns early if website is present' do
    profile_with_website.check_social_media
    expect(profile_with_website.errors).to be_empty
  end

  it 'returns early if twitter is present' do
    profile_with_twitter.check_social_media
    expect(profile_with_twitter.errors).to be_empty
  end

  it 'returns early if facebook is present' do
    profile_with_facebook.check_social_media
    expect(profile_with_facebook.errors).to be_empty
  end

  it 'returns early if instagram is present' do
    profile_with_instagram.check_social_media
    expect(profile_with_instagram.errors).to be_empty
  end

  it 'returns early if partner.partials_to_show does not include "media_information"' do
    profile_without_media_info.check_social_media
    expect(profile_without_media_info.errors).to be_empty
  end

  it 'adds an error if no social media is present and no_social_media_presence is not checked' do
    profile_no_social_media_unchecked.check_social_media
    expect(profile_no_social_media_unchecked.errors[:no_social_media_presence]).to include("must be checked if you have not provided any of Website, Twitter, Facebook, or Instagram.")
  end

  it 'does not add an error if no social media is present and no_social_media_presence is checked' do
    profile_no_social_media_checked.check_social_media
    expect(profile_no_social_media_checked.errors).to be_empty
  end
end
describe '#client_share_is_0_or_100', :phoenix do
  let(:partner_profile) { build(:partner_profile, client_share_total: client_share_total) }

  context 'when client_share_total is 0' do
    let(:client_share_total) { 0 }

    it 'does not add errors to client_share' do
      partner_profile.client_share_is_0_or_100
      expect(partner_profile.errors[:client_share]).to be_empty
    end

    it 'does not add errors to base' do
      partner_profile.client_share_is_0_or_100
      expect(partner_profile.errors[:base]).to be_empty
    end
  end

  context 'when client_share_total is 100' do
    let(:client_share_total) { 100 }

    it 'does not add errors to client_share' do
      partner_profile.client_share_is_0_or_100
      expect(partner_profile.errors[:client_share]).to be_empty
    end

    it 'does not add errors to base' do
      partner_profile.client_share_is_0_or_100
      expect(partner_profile.errors[:base]).to be_empty
    end
  end

  describe 'when client_share_total is neither 0 nor 100' do
    let(:client_share_total) { 50 } # Example value not 0 or 100

    context 'when partner_step_form feature is enabled' do
      before { allow(Flipper).to receive(:enabled?).with('partner_step_form').and_return(true) }

      it 'adds error to client_share' do
        partner_profile.client_share_is_0_or_100
        expect(partner_profile.errors[:client_share]).to include('Total client share must be 0 or 100')
      end
    end

    context 'when partner_step_form feature is not enabled' do
      before { allow(Flipper).to receive(:enabled?).with('partner_step_form').and_return(false) }

      it 'adds error to base' do
        partner_profile.client_share_is_0_or_100
        expect(partner_profile.errors[:base]).to include('Total client share must be 0 or 100')
      end
    end
  end
end
describe '#has_at_least_one_request_setting', :phoenix do
  let(:partner_profile) { build(:partner_profile, enable_child_based_requests: enable_child_based_requests, enable_individual_requests: enable_individual_requests, enable_quantity_based_requests: enable_quantity_based_requests) }

  before { partner_profile.has_at_least_one_request_setting }

  context 'when all request settings are disabled' do
    let(:enable_child_based_requests) { false }
    let(:enable_individual_requests) { false }
    let(:enable_quantity_based_requests) { false }

    context 'and partner_step_form is enabled' do
      before { allow(Flipper).to receive(:enabled?).with('partner_step_form').and_return(true) }

      it 'adds an error to enable_child_based_requests' do
        expect(partner_profile.errors[:enable_child_based_requests]).to include('At least one request type must be set')
      end
    end

    context 'and partner_step_form is disabled' do
      before { allow(Flipper).to receive(:enabled?).with('partner_step_form').and_return(false) }

      it 'adds an error to base' do
        expect(partner_profile.errors[:base]).to include('At least one request type must be set')
      end
    end
  end

  context 'when at least one request setting is enabled' do
    let(:enable_child_based_requests) { true }
    let(:enable_individual_requests) { false }
    let(:enable_quantity_based_requests) { false }

    it 'does not add any errors' do
      expect(partner_profile.errors).to be_empty
    end
  end
end
describe '#pick_up_email_addresses', :phoenix do
  let(:profile) { build(:partner_profile, pick_up_email: pick_up_email) }

  context 'when pick_up_email is nil' do
    let(:pick_up_email) { nil }

    it 'returns nil' do
      expect(profile.pick_up_email_addresses).to be_nil
    end
  end

  context 'when there are more than three email addresses' do
    let(:pick_up_email) { 'email1@example.com, email2@example.com, email3@example.com, email4@example.com' }

    it 'adds an error for too many email addresses' do
      profile.pick_up_email_addresses
      expect(profile.errors[:pick_up_email]).to include("can't have more than three email addresses")
    end
  end

  context 'when there are repeated email addresses' do
    let(:pick_up_email) { 'email1@example.com, email1@example.com, email2@example.com' }

    it 'adds an error for repeated email addresses' do
      profile.pick_up_email_addresses
      expect(profile.errors[:pick_up_email]).to include('should not have repeated email addresses')
    end
  end

  context 'when there is an invalid email address' do
    let(:pick_up_email) { 'invalid-email, email2@example.com, email3@example.com' }

    it 'adds an error for invalid email addresses' do
      profile.pick_up_email_addresses
      expect(profile.errors[:pick_up_email]).to include('is invalid')
    end
  end

  context 'when all email addresses are valid and unique' do
    let(:pick_up_email) { 'email1@example.com, email2@example.com, email3@example.com' }

    it 'does not add any errors' do
      profile.pick_up_email_addresses
      expect(profile.errors[:pick_up_email]).to be_empty
    end
  end
end
end
