
require "rails_helper"

RSpec.describe AccountRequest do
describe '#get_by_identity_token', :phoenix do
  let(:account_request) { create(:account_request) }
  let(:identity_token) { JWT.encode({ account_request_id: account_request.id }, Rails.application.secret_key_base, 'HS256') }

  it 'returns the account request when given a valid identity token' do
    allow(AccountRequest).to receive(:find_by).with(id: account_request.id).and_return(account_request)
    expect(AccountRequest.get_by_identity_token(identity_token)).to eq(account_request)
  end

  it 'returns nil when no account request is found for a valid identity token' do
    allow(AccountRequest).to receive(:find_by).with(id: account_request.id).and_return(nil)
    expect(AccountRequest.get_by_identity_token(identity_token)).to be_nil
  end

  it 'returns nil for an invalid identity token due to decoding error' do
    invalid_token = 'invalid.token.string'
    expect(AccountRequest.get_by_identity_token(invalid_token)).to be_nil
  end

  it 'returns nil when a StandardError is raised during decoding' do
    allow(JWT).to receive(:decode).and_raise(StandardError)
    expect(AccountRequest.get_by_identity_token(identity_token)).to be_nil
  end
end
describe '#identity_token', :phoenix do
  let(:account_request) { create(:account_request) }

  context 'when the account request is persisted' do
    it 'encodes a JWT token with the correct account_request_id' do
      token = account_request.identity_token
      decoded_token = JWT.decode(token, Rails.application.secret_key_base, true, { algorithm: 'HS256' })
      expect(decoded_token.first['account_request_id']).to eq(account_request.id)
    end
  end

  context 'when the account request is not persisted' do
    let(:account_request) { build(:account_request) }

    it 'raises an error indicating the id is missing' do
      expect { account_request.identity_token }.to raise_error('must have an id')
    end
  end
end
describe '#confirmed?', :phoenix do
  let(:account_request) { build(:account_request, status: status) }

  context 'when user is confirmed and admin is not approved' do
    let(:status) { 'user_confirmed' }

    it 'returns true when user is confirmed' do
      expect(account_request.confirmed?).to eq(true)
    end
  end

  context 'when user is not confirmed and admin is approved' do
    let(:status) { 'admin_approved' }

    it 'returns true when admin is approved' do
      expect(account_request.confirmed?).to eq(true)
    end
  end

  context 'when both user is confirmed and admin is approved' do
    let(:status) { 'user_confirmed_and_admin_approved' }

    it 'returns true when both user is confirmed and admin is approved' do
      expect(account_request.confirmed?).to eq(true)
    end
  end

  context 'when neither user is confirmed nor admin is approved' do
    let(:status) { 'pending' }

    it 'returns false when neither user is confirmed nor admin is approved' do
      expect(account_request.confirmed?).to eq(false)
    end
  end
end
describe '#processed?', :phoenix do
  let(:organization) { build(:organization) }
  let(:account_request_with_org) { build(:account_request, organization: organization) }
  let(:account_request_without_org) { build(:account_request, organization: nil) }

  it 'returns true when organization is present' do
    expect(account_request_with_org.processed?).to be true
  end

  it 'returns false when organization is not present' do
    expect(account_request_without_org.processed?).to be false
  end
end
describe '#can_be_closed?', :phoenix do
  let(:account_request) { build(:account_request, status: status) }

  context 'when status is started' do
    let(:status) { 'started' }

    it 'returns true when the status is started' do
      expect(account_request.can_be_closed?).to eq(true)
    end
  end

  context 'when status is user_confirmed' do
    let(:status) { 'user_confirmed' }

    it 'returns true when the status is user_confirmed' do
      expect(account_request.can_be_closed?).to eq(true)
    end
  end

  context 'when status is neither started nor user_confirmed' do
    let(:status) { 'pending' }

    it 'returns false when the status is neither started nor user_confirmed' do
      expect(account_request.can_be_closed?).to eq(false)
    end
  end
end
describe '#confirm!', :phoenix do
  let(:account_request) { create(:account_request) }

  it 'updates confirmed_at to current time' do
    account_request.confirm!
    expect(account_request.confirmed_at).to be_within(1.second).of(Time.current)
  end

  it 'updates status to user_confirmed' do
    account_request.confirm!
    expect(account_request.status).to eq('user_confirmed')
  end

  it 'enqueues an approval request email' do
    expect { account_request.confirm! }.to have_enqueued_job.on_queue('mailers')
  end

  describe 'when update fails' do
    before do
      allow(account_request).to receive(:update!).and_raise(ActiveRecord::RecordInvalid)
    end

    it 'raises ActiveRecord::RecordInvalid error' do
      expect { account_request.confirm! }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  describe 'when email delivery fails' do
    before do
      allow(AccountRequestMailer).to receive_message_chain(:approval_request, :deliver_later).and_raise(StandardError)
    end

    it 'raises StandardError' do
      expect { account_request.confirm! }.to raise_error(StandardError)
    end
  end
end
describe '#reject!', :phoenix do
  let(:account_request) { create(:account_request) }
  let(:rejection_reason) { 'Insufficient information provided' }

  it 'updates the status to rejected' do
    account_request.reject!(rejection_reason)
    expect(account_request.status).to eq('rejected')
  end

  it 'sets the rejection reason' do
    account_request.reject!(rejection_reason)
    expect(account_request.rejection_reason).to eq(rejection_reason)
  end

  it 'sends a rejection email' do
    mailer_double = instance_double(AccountRequestMailer)
    allow(AccountRequestMailer).to receive(:rejection).with(account_request_id: account_request.id).and_return(mailer_double)
    expect(mailer_double).to receive(:deliver_later)
    account_request.reject!(rejection_reason)
  end

  describe 'when update fails' do
    before do
      allow(account_request).to receive(:update!).and_raise(ActiveRecord::RecordInvalid)
    end

    it 'does not send a rejection email' do
      expect(AccountRequestMailer).not_to receive(:rejection)
      expect { account_request.reject!(rejection_reason) }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  describe 'when email delivery fails' do
    before do
      allow(AccountRequestMailer).to receive(:rejection).and_raise(Net::SMTPFatalError)
    end

    it 'raises an email delivery failure error' do
      expect { account_request.reject!(rejection_reason) }.to raise_error(Net::SMTPFatalError)
    end
  end
end
describe '#close!', :phoenix do
  let(:account_request) { build(:account_request, status: account_status) }
  let(:account_status) { 'open' }

  it 'raises an error if the account cannot be closed' do
    allow(account_request).to receive(:can_be_closed?).and_return(false)
    expect { account_request.close!('Some reason') }.to raise_error('Cannot be closed from this state')
  end

  context 'when the account can be closed' do
    before do
      allow(account_request).to receive(:can_be_closed?).and_return(true)
    end

    it 'updates the status to admin_closed' do
      account_request.close!('Some reason')
      expect(account_request.status).to eq('admin_closed')
    end

    it 'sets the rejection reason' do
      account_request.close!('Some reason')
      expect(account_request.rejection_reason).to eq('Some reason')
    end
  end
end
describe '#email_not_already_used_by_organization', :phoenix do
  let(:organization) { build(:organization, email: 'unique@example.com') }
  let(:existing_organization) { create(:organization, email: 'existing@example.com') }

  it 'does not add an error if the email is not associated with any organization' do
    allow(Organization).to receive(:find_by).with(email: 'unique@example.com').and_return(nil)
    organization.email_not_already_used_by_organization
    expect(organization.errors[:email]).to be_empty
  end

  it 'does not add an error if the email is associated with the current organization' do
    allow(Organization).to receive(:find_by).with(email: 'unique@example.com').and_return(organization)
    organization.email_not_already_used_by_organization
    expect(organization.errors[:email]).to be_empty
  end

  it 'adds an error if the email is associated with a different organization' do
    allow(Organization).to receive(:find_by).with(email: 'existing@example.com').and_return(existing_organization)
    organization.email = 'existing@example.com'
    organization.email_not_already_used_by_organization
    expect(organization.errors[:email]).to include('already used by an existing Organization')
  end
end
describe '#email_not_already_used_by_user', :phoenix do
  let(:organization) { create(:organization) }
  let(:user_with_same_email) { build(:user, email: 'test@example.com', organization: user_organization) }
  let(:user_organization) { nil }

  it 'adds an error when a user with the same email exists and no organization is provided' do
    allow(User).to receive(:find_by).with(email: 'test@example.com').and_return(user_with_same_email)
    account_request = build(:account_request, email: 'test@example.com', organization: nil)
    account_request.email_not_already_used_by_user
    expect(account_request.errors[:email]).to include('already used by an existing User')
  end

  context 'when a different organization is provided' do
    let(:user_organization) { create(:organization) }

    it 'adds an error when a user with the same email exists and a different organization is provided' do
      allow(User).to receive(:find_by).with(email: 'test@example.com').and_return(user_with_same_email)
      account_request = build(:account_request, email: 'test@example.com', organization: organization)
      account_request.email_not_already_used_by_user
      expect(account_request.errors[:email]).to include('already used by an existing User')
    end
  end

  context 'when the same organization is provided' do
    let(:user_organization) { organization }

    it 'does not add an error when a user with the same email exists and the same organization is provided' do
      allow(User).to receive(:find_by).with(email: 'test@example.com').and_return(user_with_same_email)
      account_request = build(:account_request, email: 'test@example.com', organization: organization)
      account_request.email_not_already_used_by_user
      expect(account_request.errors[:email]).to be_empty
    end
  end

  it 'does not add an error when no user with the same email exists' do
    allow(User).to receive(:find_by).with(email: 'test@example.com').and_return(nil)
    account_request = build(:account_request, email: 'test@example.com', organization: organization)
    account_request.email_not_already_used_by_user
    expect(account_request.errors[:email]).to be_empty
  end
end
end
