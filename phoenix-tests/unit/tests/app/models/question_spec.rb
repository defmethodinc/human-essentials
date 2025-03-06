
require "rails_helper"

RSpec.describe Question do
describe '#punctuate', :phoenix do
  let(:question) { build(:question) }

  it 'returns an empty string when errors array is empty' do
    errors = []
    expect(question.punctuate(errors)).to eq('')
  end

  it 'appends a period to each error when no redundant error is present' do
    errors = ['error1', 'error2']
    expect(question.punctuate(errors)).to eq('error1. error2. ')
  end

  it 'removes the specific redundant error from the errors array' do
    errors = ['For banks and for partners can\'t both be unchecked']
    expect(question.punctuate(errors)).to eq('')
  end

  it 'removes multiple instances of the specific redundant error' do
    errors = ['For banks and for partners can\'t both be unchecked', 'For banks and for partners can\'t both be unchecked']
    expect(question.punctuate(errors)).to eq('')
  end

  it 'retains non-redundant errors and removes redundant ones' do
    errors = ['For banks and for partners can\'t both be unchecked', 'error1', 'For banks and for partners can\'t both be unchecked', 'error2']
    expect(question.punctuate(errors)).to eq('error1. error2. ')
  end
end
describe '#remove_redundant_error', :phoenix do
  let(:question) { build(:question) }
  let(:errors_with_redundant) { ["For banks and for partners can't both be unchecked", "Another error"] }
  let(:errors_without_redundant) { ["Another error"] }

  it 'removes the redundant error when present' do
    result = question.remove_redundant_error(errors_with_redundant)
    expect(result).not_to include("For banks and for partners can't both be unchecked")
  end

  it 'returns the same errors when the redundant error is not present' do
    result = question.remove_redundant_error(errors_without_redundant)
    expect(result).to eq(errors_without_redundant)
  end
end
end
