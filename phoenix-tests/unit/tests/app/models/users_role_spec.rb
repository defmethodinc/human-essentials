
require "rails_helper"

RSpec.describe UsersRole do
describe '#current_role_for', :phoenix do
  let(:user_with_last_role) { build(:user, last_role: build(:role, name: 'ORG_USER')) }
  let(:user_with_roles) { build(:user) }
  let(:super_admin_role) { build(:role, name: 'SUPER_ADMIN') }
  let(:org_admin_role) { build(:role, name: 'ORG_ADMIN') }
  let(:org_user_role) { build(:role, name: 'ORG_USER') }
  let(:partner_role) { build(:role, name: 'PARTNER') }

  before do
    allow(user_with_roles).to receive(:roles).and_return([partner_role, org_user_role, org_admin_role, super_admin_role])
  end

  it 'returns nil if user is nil' do
    expect(UsersRole.current_role_for(nil)).to be_nil
  end

  it 'returns last_role if user has a last_role' do
    expect(UsersRole.current_role_for(user_with_last_role)).to eq(user_with_last_role.last_role)
  end

  describe 'when user has roles' do
    it 'returns the first role found in role_order' do
      expect(UsersRole.current_role_for(user_with_roles)).to eq(super_admin_role)
    end

    it 'returns nil if no roles match the role_order' do
      allow(user_with_roles).to receive(:roles).and_return([])
      expect(UsersRole.current_role_for(user_with_roles)).to be_nil
    end
  end

  it 'returns nil if user has no roles' do
    user_without_roles = build(:user)
    allow(user_without_roles).to receive(:roles).and_return([])
    expect(UsersRole.current_role_for(user_without_roles)).to be_nil
  end
end
describe '#set_last_role_for', :phoenix do
  let(:user) { create(:user) }
  let(:role) { create(:role) }

  context 'when a UsersRole is found' do
    let!(:users_role) { create(:users_role, user: user, role: role) }

    it 'updates the user last_role_id to users_role.id' do
      UsersRole.set_last_role_for(user, role)
      expect(user.reload.last_role_id).to eq(users_role.id)
    end
  end

  context 'when no UsersRole is found' do
    it 'does not update the user last_role_id' do
      expect { UsersRole.set_last_role_for(user, role) }.not_to change { user.reload.last_role_id }
    end
  end
end
end
