
require "rails_helper"

RSpec.describe NDBNMember do
describe '#full_name', :phoenix do
  let(:ndbn_member) { build(:ndbn_member, ndbn_member_id: member_id, account_name: account_name) }

  context 'when both ndbn_member_id and account_name are present' do
    let(:member_id) { 123 }
    let(:account_name) { 'Test Account' }

    it 'returns a concatenated string with id and account name' do
      expect(ndbn_member.full_name).to eq('123 - Test Account')
    end
  end

  context 'when account_name is nil' do
    let(:member_id) { 123 }
    let(:account_name) { nil }

    it 'returns a string with ndbn_member_id and a hyphen' do
      expect(ndbn_member.full_name).to eq('123 - ')
    end
  end

  context 'when account_name is empty' do
    let(:member_id) { 123 }
    let(:account_name) { '' }

    it 'returns a string with ndbn_member_id and a hyphen' do
      expect(ndbn_member.full_name).to eq('123 - ')
    end
  end

  context 'when ndbn_member_id is nil' do
    let(:member_id) { nil }
    let(:account_name) { 'Test Account' }

    it 'returns a string with a hyphen and account name' do
      expect(ndbn_member.full_name).to eq(' - Test Account')
    end
  end

  context 'when ndbn_member_id is empty' do
    let(:member_id) { '' }
    let(:account_name) { 'Test Account' }

    it 'returns a string with a hyphen and account name' do
      expect(ndbn_member.full_name).to eq(' - Test Account')
    end
  end

  context 'when both ndbn_member_id and account_name are nil' do
    let(:member_id) { nil }
    let(:account_name) { nil }

    it 'returns a string with just a hyphen' do
      expect(ndbn_member.full_name).to eq(' - ')
    end
  end

  context 'when both ndbn_member_id and account_name are empty' do
    let(:member_id) { '' }
    let(:account_name) { '' }

    it 'returns a string with just a hyphen' do
      expect(ndbn_member.full_name).to eq(' - ')
    end
  end
end
end
