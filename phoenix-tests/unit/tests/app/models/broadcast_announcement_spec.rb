
require "rails_helper"

RSpec.describe BroadcastAnnouncement do
describe '#expired?', :phoenix do
  let(:broadcast_announcement) { build(:broadcast_announcement, expiry: expiry_date) }

  context 'when expiry is nil' do
    let(:expiry_date) { nil }

    it 'returns false when expiry is nil' do
      expect(broadcast_announcement.expired?).to eq(false)
    end
  end

  context 'when expiry is in the past' do
    let(:expiry_date) { Time.zone.today - 1.day }

    it 'returns true when expiry is in the past' do
      expect(broadcast_announcement.expired?).to eq(true)
    end
  end

  context 'when expiry is today' do
    let(:expiry_date) { Time.zone.today }

    it 'returns false when expiry is today' do
      expect(broadcast_announcement.expired?).to eq(false)
    end
  end

  context 'when expiry is in the future' do
    let(:expiry_date) { Time.zone.today + 1.day }

    it 'returns false when expiry is in the future' do
      expect(broadcast_announcement.expired?).to eq(false)
    end
  end
end
describe '#filter_announcements', :phoenix do
  let(:organization) { create(:organization) }
  let(:other_organization) { create(:organization) }
  let(:today) { Time.zone.today }

  let!(:announcement_with_org) { create(:broadcast_announcement, organization: organization, expiry: today + 1.day) }
  let!(:announcement_with_other_org) { create(:broadcast_announcement, organization: other_organization, expiry: today + 1.day) }
  let!(:announcement_with_nil_expiry) { create(:broadcast_announcement, organization: organization, expiry: nil) }
  let!(:announcement_with_future_expiry) { create(:broadcast_announcement, organization: organization, expiry: today + 1.day) }
  let!(:announcement_with_past_expiry) { create(:broadcast_announcement, organization: organization, expiry: today - 1.day) }

  it 'includes announcements with the specified organization_id' do
    result = BroadcastAnnouncement.filter_announcements(organization.id)
    expect(result).to include(announcement_with_org)
  end

  it 'excludes announcements with a different organization_id' do
    result = BroadcastAnnouncement.filter_announcements(organization.id)
    expect(result).not_to include(announcement_with_other_org)
  end

  it 'includes announcements with expiry as nil' do
    result = BroadcastAnnouncement.filter_announcements(organization.id)
    expect(result).to include(announcement_with_nil_expiry)
  end

  it 'includes announcements with expiry date greater than or equal to today' do
    result = BroadcastAnnouncement.filter_announcements(organization.id)
    expect(result).to include(announcement_with_future_expiry)
  end

  it 'excludes announcements with expiry date less than today' do
    result = BroadcastAnnouncement.filter_announcements(organization.id)
    expect(result).not_to include(announcement_with_past_expiry)
  end

  it 'orders announcements by created_at in descending order' do
    result = BroadcastAnnouncement.filter_announcements(organization.id)
    expect(result).to eq([announcement_with_future_expiry, announcement_with_nil_expiry, announcement_with_org])
  end
end
end
