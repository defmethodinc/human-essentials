
require "rails_helper"

RSpec.describe Partners::FamilyRequest do
describe '#initialize', :phoenix do
  let(:params) { { some_key: 'some_value' } }
  let(:partner) { Partner.new(name: 'Test Partner') }
  let(:initial_items) { 3 }

  it 'initializes items with the correct size when initial_items is provided' do
    family_request = Partners::FamilyRequest.new(params, initial_items: initial_items)
    expect(family_request.items.size).to eq(initial_items)
  end

  it 'does not initialize items when initial_items is nil' do
    family_request = Partners::FamilyRequest.new(params)
    expect(family_request.items).to be_nil
  end

  it 'assigns the correct partner when partner is provided' do
    family_request = Partners::FamilyRequest.new(params, partner: partner)
    expect(family_request.partner).to eq(partner)
  end

  it 'does not assign a partner when partner is nil' do
    family_request = Partners::FamilyRequest.new(params)
    expect(family_request.partner).to be_nil
  end

  it 'correctly calls super with params' do
    family_request = Partners::FamilyRequest.new(params)
    expect(family_request.some_key).to eq('some_value')
  end
end
describe '#items_attributes=', :phoenix do
  let(:valid_attributes) do
    {
      '0' => { item_id: build(:item).id, person_count: 2 },
      '1' => { item_id: build(:item).id, person_count: 3 }
    }
  end

  let(:missing_item_id_attributes) do
    {
      '0' => { person_count: 2 }
    }
  end

  let(:missing_person_count_attributes) do
    {
      '0' => { item_id: build(:item).id }
    }
  end

  let(:additional_keys_attributes) do
    {
      '0' => { item_id: build(:item).id, person_count: 2, extra_key: 'extra_value' }
    }
  end

  let(:invalid_item_id_attributes) do
    {
      '0' => { item_id: 'invalid_id', person_count: 2 }
    }
  end

  let(:invalid_person_count_attributes) do
    {
      '0' => { item_id: build(:item).id, person_count: 'invalid_count' }
    }
  end

  it 'creates the correct number of Item objects with valid attributes' do
    family_request = Partners::FamilyRequest.new
    family_request.items_attributes = valid_attributes
    expect(family_request.instance_variable_get(:@items).size).to eq(2)
  end

  it 'creates Item objects with correct attributes' do
    family_request = Partners::FamilyRequest.new
    family_request.items_attributes = valid_attributes
    expect(family_request.instance_variable_get(:@items).first).to have_attributes(item_id: valid_attributes['0'][:item_id], person_count: 2)
  end

  describe 'when attributes are missing item_id' do
    it 'sets item_id to nil' do
      family_request = Partners::FamilyRequest.new
      family_request.items_attributes = missing_item_id_attributes
      expect(family_request.instance_variable_get(:@items).first).to have_attributes(item_id: nil, person_count: 2)
    end
  end

  describe 'when attributes are missing person_count' do
    it 'sets person_count to nil' do
      family_request = Partners::FamilyRequest.new
      family_request.items_attributes = missing_person_count_attributes
      expect(family_request.instance_variable_get(:@items).first).to have_attributes(item_id: missing_person_count_attributes['0'][:item_id], person_count: nil)
    end
  end

  describe 'when attributes contain additional keys' do
    it 'ignores additional keys and sets correct attributes' do
      family_request = Partners::FamilyRequest.new
      family_request.items_attributes = additional_keys_attributes
      expect(family_request.instance_variable_get(:@items).first).to have_attributes(item_id: additional_keys_attributes['0'][:item_id], person_count: 2)
    end
  end

  describe 'when attributes have invalid data types' do
    it 'handles invalid data types for item_id' do
      family_request = Partners::FamilyRequest.new
      family_request.items_attributes = invalid_item_id_attributes
      expect(family_request.instance_variable_get(:@items).first).to have_attributes(item_id: 'invalid_id', person_count: 2)
    end

    it 'handles invalid data types for person_count' do
      family_request = Partners::FamilyRequest.new
      family_request.items_attributes = invalid_person_count_attributes
      expect(family_request.instance_variable_get(:@items).first).to have_attributes(item_id: invalid_person_count_attributes['0'][:item_id], person_count: 'invalid_count')
    end
  end
end
describe "#new_with_attrs", :phoenix do
  let(:empty_attrs) { [] }
  let(:multiple_attrs) { [{ key1: 'value1' }, { key2: 'value2' }] }
  let(:invalid_attrs) { [{ invalid_key: nil }] }
  let(:duplicate_attrs) { [{ key: 'value' }, { key: 'value' }] }
  let(:boundary_attrs) { [{ key: '' }, { key: 'a' * 256 }] }
  let(:non_array_input) { 'not an array' }

  it "creates a request with no attributes" do
    request = Partners::FamilyRequest.new_with_attrs(empty_attrs)
    expect(request.items_attributes).to eq({})
  end

  it "creates a request with multiple attributes" do
    request = Partners::FamilyRequest.new_with_attrs(multiple_attrs)
    expect(request.items_attributes).to eq({0 => { key1: 'value1' }, 1 => { key2: 'value2' }})
  end

  it "creates a request with invalid attributes" do
    request = Partners::FamilyRequest.new_with_attrs(invalid_attrs)
    expect(request.items_attributes).to eq({0 => { invalid_key: nil }})
  end

  it "creates a request with duplicate attributes" do
    request = Partners::FamilyRequest.new_with_attrs(duplicate_attrs)
    expect(request.items_attributes).to eq({0 => { key: 'value' }, 1 => { key: 'value' }})
  end

  it "creates a request with boundary values for attributes" do
    request = Partners::FamilyRequest.new_with_attrs(boundary_attrs)
    expect(request.items_attributes).to eq({0 => { key: '' }, 1 => { key: 'a' * 256 }})
  end

  it "raises an error for non-array input" do
    expect { Partners::FamilyRequest.new_with_attrs(non_array_input) }.to raise_error(NoMethodError)
  end

  describe "when attributes are empty" do
    it "initializes with default item" do
      request = Partners::FamilyRequest.new_with_attrs(empty_attrs)
      expect(request.items_attributes).to eq({})
    end
  end

  describe "when attributes are present" do
    it "assigns attributes correctly" do
      request = Partners::FamilyRequest.new_with_attrs(multiple_attrs)
      expect(request.items_attributes).to eq({0 => { key1: 'value1' }, 1 => { key2: 'value2' }})
    end
  end
end
end
