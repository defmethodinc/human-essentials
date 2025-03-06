
require "rails_helper"

RSpec.describe Partners::AuthorizedFamilyMember do
describe '#display_name', :phoenix do
  let(:authorized_family_member_with_full_name) { Partners::AuthorizedFamilyMember.new(first_name: 'John', last_name: 'Doe') }
  let(:authorized_family_member_with_first_name_only) { Partners::AuthorizedFamilyMember.new(first_name: 'John', last_name: nil) }
  let(:authorized_family_member_with_last_name_only) { Partners::AuthorizedFamilyMember.new(first_name: nil, last_name: 'Doe') }
  let(:authorized_family_member_with_no_name) { Partners::AuthorizedFamilyMember.new(first_name: nil, last_name: nil) }

  it 'returns full name when both first_name and last_name are present' do
    expect(authorized_family_member_with_full_name.display_name).to eq('John Doe')
  end

  it 'returns first_name when last_name is nil' do
    expect(authorized_family_member_with_first_name_only.display_name).to eq('John')
  end

  it 'returns last_name when first_name is nil' do
    expect(authorized_family_member_with_last_name_only.display_name).to eq('Doe')
  end

  it 'returns an empty string when both first_name and last_name are nil' do
    expect(authorized_family_member_with_no_name.display_name).to eq('')
  end
end
end
