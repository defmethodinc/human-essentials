
require "rails_helper"

RSpec.describe User do
describe '#normalize_blank_name_to_nil', :phoenix do
  let(:user_with_nil_name) { build(:user, name: nil) }
  let(:user_with_empty_name) { build(:user, name: '') }
  let(:user_with_whitespace_name) { build(:user, name: '   ') }
  let(:user_with_non_blank_name) { build(:user, name: 'Valid Name') }

  it 'sets name to nil if name is nil' do
    user_with_nil_name.normalize_blank_name_to_nil
    expect(user_with_nil_name.name).to be_nil
  end

  it 'sets name to nil if name is an empty string' do
    user_with_empty_name.normalize_blank_name_to_nil
    expect(user_with_empty_name.name).to be_nil
  end

  it 'sets name to nil if name is a string with only whitespace' do
    user_with_whitespace_name.normalize_blank_name_to_nil
    expect(user_with_whitespace_name.name).to be_nil
  end

  it 'does not change name if name is a non-blank string' do
    user_with_non_blank_name.normalize_blank_name_to_nil
    expect(user_with_non_blank_name.name).to eq('Valid Name')
  end
end
describe '#display_name', :phoenix do
  let(:user_with_name) { build(:user, name: 'Diaper McDiaperface') }
  let(:user_without_name) { build(:user, name: nil) }

  it 'returns the name when present' do
    expect(user_with_name.display_name).to eq('Diaper McDiaperface')
  end

  it 'returns "Name Not Provided" when name is not present' do
    expect(user_without_name.display_name).to eq('Name Not Provided')
  end
end
describe "#formatted_email", :phoenix do
  let(:user_with_email) { build(:user, email: "user@example.com", name: "User Name") }
  let(:user_without_email) { build(:user, email: nil, name: "User Name") }

  it "returns formatted email when email is present" do
    expect(user_with_email.formatted_email).to eq("User Name <user@example.com>")
  end

  it "returns an empty string when email is not present" do
    expect(user_without_email.formatted_email).to eq("")
  end
end
describe '#password_complexity', :phoenix do
  let(:user_with_blank_password) { build(:user, password: '') }
  let(:user_with_special_char_password) { build(:user, password: 'password!') }
  let(:user_without_special_char_password) { build(:user, password: 'password') }

  it 'returns nil if password is blank' do
    expect(user_with_blank_password.password_complexity).to be_nil
  end

  it 'returns nil if password contains at least one special character' do
    expect(user_with_special_char_password.password_complexity).to be_nil
  end

  it 'adds an error if password does not contain any special characters' do
    user_without_special_char_password.password_complexity
    expect(user_without_special_char_password.errors[:password]).to include('Complexity requirement not met. Please use at least 1 special character')
  end
end
describe "#invitation_status", :phoenix do
  let(:user_joined) { build(:user, current_sign_in_at: Time.current) }
  let(:user_accepted) { build(:user, invitation_accepted_at: Time.current, current_sign_in_at: nil) }
  let(:user_invited) { build(:user, invitation_sent_at: Time.current, current_sign_in_at: nil, invitation_accepted_at: nil) }
  let(:user_none) { build(:user, current_sign_in_at: nil, invitation_accepted_at: nil, invitation_sent_at: nil) }

  it "returns 'joined' when current_sign_in_at is present" do
    expect(user_joined.invitation_status).to eq('joined')
  end

  it "returns 'accepted' when invitation_accepted_at is present and current_sign_in_at is not present" do
    expect(user_accepted.invitation_status).to eq('accepted')
  end

  it "returns 'invited' when invitation_sent_at is present and neither current_sign_in_at nor invitation_accepted_at are present" do
    expect(user_invited.invitation_status).to eq('invited')
  end

  it "returns nil when none of the invitation attributes are present" do
    expect(user_none.invitation_status).to be_nil
  end
end
describe '#kind', :phoenix do
  let(:organization) { build(:organization) }
  let(:partner) { build(:partner) }

  let(:super_admin_user) { build(:super_admin) }
  let(:org_admin_user) { build(:organization_admin, organization: organization) }
  let(:org_user) { build(:user, organization: organization) }
  let(:partner_user) { build(:partner_user, partner: partner) }
  let(:normal_user) { build(:user, :no_roles) }

  it 'returns super when user has SUPER_ADMIN role' do
    expect(super_admin_user.kind).to eq("super")
  end

  it 'returns admin when user has ORG_ADMIN role in the organization' do
    expect(org_admin_user.kind).to eq("admin")
  end

  it 'returns normal when user has ORG_USER role in the organization' do
    expect(org_user.kind).to eq("normal")
  end

  it 'returns partner when user has PARTNER role in the partner' do
    expect(partner_user.kind).to eq("partner")
  end

  it 'returns normal when user has no specific role' do
    expect(normal_user.kind).to eq("normal")
  end
end
describe "#is_admin?", :phoenix do
  let(:organization) { create(:organization) }
  let(:user_with_org_admin_role) { create(:organization_admin, organization: organization) }
  let(:user_with_super_admin_role) { create(:super_admin) }
  let(:user_with_both_roles) do
    user = create(:organization_admin, organization: organization)
    user.add_role(Role::SUPER_ADMIN)
    user
  end
  let(:user_with_no_roles) { create(:user, :no_roles) }

  it "returns true if user has ORG_ADMIN role for the organization" do
    expect(user_with_org_admin_role.is_admin?(organization)).to be true
  end

  it "returns false if user does not have ORG_ADMIN role for the organization" do
    expect(user_with_no_roles.is_admin?(organization)).to be false
  end

  it "returns true if user has SUPER_ADMIN role" do
    expect(user_with_super_admin_role.is_admin?(organization)).to be true
  end

  it "returns false if user does not have SUPER_ADMIN role" do
    expect(user_with_no_roles.is_admin?(organization)).to be false
  end

  it "returns true if user has both ORG_ADMIN and SUPER_ADMIN roles" do
    expect(user_with_both_roles.is_admin?(organization)).to be true
  end

  it "returns false if user has neither ORG_ADMIN nor SUPER_ADMIN roles" do
    expect(user_with_no_roles.is_admin?(organization)).to be false
  end
end
describe "#switchable_roles", :phoenix do
  let(:user) { create(:user) }
  let(:org_admin_role) { build(:role, name: Role::ORG_ADMIN.to_s, resource_id: 1) }
  let(:org_user_role) { build(:role, name: Role::ORG_USER.to_s, resource_id: 1) }
  let(:different_resource_org_admin_role) { build(:role, name: Role::ORG_ADMIN.to_s, resource_id: 2) }

  it "returns an empty array when there are no roles" do
    user.roles = []
    expect(user.switchable_roles).to eq([])
  end

  it "returns the same role when there is only one ORG_ADMIN role" do
    user.roles = [org_admin_role]
    expect(user.switchable_roles).to eq([org_admin_role])
  end

  it "returns the same role when there is only one ORG_USER role" do
    user.roles = [org_user_role]
    expect(user.switchable_roles).to eq([org_user_role])
  end

  it "returns all roles when there are multiple roles and no ORG_ADMIN" do
    user.roles = [org_user_role, build(:role, name: 'other_role', resource_id: 1)]
    expect(user.switchable_roles).to match_array(user.roles)
  end

  it "removes ORG_USER roles when ORG_ADMIN is present in the same resource group" do
    user.roles = [org_admin_role, org_user_role]
    expect(user.switchable_roles).to eq([org_admin_role])
  end

  it "does not remove ORG_USER roles when ORG_ADMIN is present in a different resource group" do
    user.roles = [different_resource_org_admin_role, org_user_role]
    expect(user.switchable_roles).to match_array(user.roles)
  end
end
describe '#flipper_id', :phoenix do
  let(:user) { build(:user) }

  it 'returns the correct flipper_id format for a valid user id' do
    expect(user.flipper_id).to eq("User: {user.id}")
  end

  context 'when user id is nil' do
    let(:user) { build(:user, id: nil) }

    it 'returns flipper_id with empty id' do
      expect(user.flipper_id).to eq('User:')
    end
  end

  context 'when user id is a non-integer value' do
    let(:user) { build(:user, id: 'non-integer') }

    it 'returns flipper_id with non-integer id' do
      expect(user.flipper_id).to eq('User:non-integer')
    end
  end
end
describe '#reinvitable?', :phoenix do
  let(:user_invited_long_ago) { build(:user, invitation_status: 'invited', invitation_sent_at: 8.days.ago) }
  let(:user_recently_invited) { build(:user, invitation_status: 'invited', invitation_sent_at: 6.days.ago) }
  let(:user_not_invited) { build(:user, invitation_status: 'not_invited') }

  it 'returns true when invitation_status is invited and invitation_sent_at is more than 7 days ago' do
    expect(user_invited_long_ago.reinvitable?).to be true
  end

  it 'returns false when invitation_status is invited and invitation_sent_at is less than or equal to 7 days ago' do
    expect(user_recently_invited.reinvitable?).to be false
  end

  it 'returns false when invitation_status is not invited' do
    expect(user_not_invited.reinvitable?).to be false
  end
end
describe '.from_omniauth', :phoenix do
  let(:user) { build(:user, email: 'existing_user@example.com') }
  let(:access_token_with_email) { double('AccessToken', info: { 'email' => user.email }) }
  let(:access_token_without_email) { double('AccessToken', info: {}) }

  it 'returns a user when a user with the email exists' do
    allow(User).to receive(:find_by).with(email: user.email).and_return(user)
    expect(User.from_omniauth(access_token_with_email)).to eq(user)
  end

  it 'returns nil when no user with the email exists' do
    allow(User).to receive(:find_by).with(email: 'non_existent@example.com').and_return(nil)
    expect(User.from_omniauth(double('AccessToken', info: { 'email' => 'non_existent@example.com' }))).to be_nil
  end

  describe 'when access_token does not contain email' do
    it 'returns nil for missing email' do
      expect(User.from_omniauth(access_token_without_email)).to be_nil
    end
  end
end
end
