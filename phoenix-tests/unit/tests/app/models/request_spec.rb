
require "rails_helper"

RSpec.describe Request do
describe "#total_items", :phoenix do
  let(:request) { build(:request, request_items: request_items) }

  context "when request_items is empty" do
    let(:request_items) { [] }

    it "returns 0" do
      expect(request.total_items).to eq(0)
    end
  end

  context "when request_items have positive quantities" do
    let(:request_items) { [{ "item_id" => 1, "quantity" => 5 }, { "item_id" => 2, "quantity" => 10 }] }

    it "sums up positive quantities correctly" do
      expect(request.total_items).to eq(15)
    end
  end

  context "when all quantities are zero" do
    let(:request_items) { [{ "item_id" => 1, "quantity" => 0 }, { "item_id" => 2, "quantity" => 0 }] }

    it "returns 0" do
      expect(request.total_items).to eq(0)
    end
  end

  context "when request_items have negative quantities" do
    let(:request_items) { [{ "item_id" => 1, "quantity" => -5 }, { "item_id" => 2, "quantity" => -10 }] }

    it "handles negative quantities correctly" do
      expect(request.total_items).to eq(-15)
    end
  end

  context "when request_items have a mix of positive, zero, and negative quantities" do
    let(:request_items) { [{ "item_id" => 1, "quantity" => 5 }, { "item_id" => 2, "quantity" => 0 }, { "item_id" => 3, "quantity" => -3 }] }

    it "sums up a mix of positive, zero, and negative quantities correctly" do
      expect(request.total_items).to eq(2)
    end
  end
end
describe '#user_email', :phoenix do
  let(:user) { build(:user) }
  let(:partner) { build(:partner) }

  context 'when partner_user_id is present' do
    let(:request_with_user) { build(:request, partner_user_id: user.id) }

    it 'returns the email of the user with partner_user_id' do
      allow(User).to receive(:find_by).with(id: user.id).and_return(user)
      expect(request_with_user.user_email).to eq(user.email)
    end

    it 'returns nil if the user with partner_user_id does not exist' do
      allow(User).to receive(:find_by).with(id: user.id).and_return(nil)
      expect(request_with_user.user_email).to be_nil
    end
  end

  context 'when partner_user_id is not present' do
    let(:request_with_partner) { build(:request, partner_id: partner.id) }

    it 'returns the email of the partner with partner_id' do
      allow(Partner).to receive(:find_by).with(id: partner.id).and_return(partner)
      expect(request_with_partner.user_email).to eq(partner.email)
    end

    it 'returns nil if the partner with partner_id does not exist' do
      allow(Partner).to receive(:find_by).with(id: partner.id).and_return(nil)
      expect(request_with_partner.user_email).to be_nil
    end
  end
end
describe "#request_type_label", :phoenix do
  let(:request_nil_type) { build(:request, request_type: nil) }
  let(:request_empty_type) { build(:request, request_type: '') }
  let(:request_single_char_type) { build(:request, request_type: 'a') }
  let(:request_multi_char_type) { build(:request, request_type: 'abc') }

  it "returns nil when request_type is nil" do
    expect(request_nil_type.request_type_label).to be_nil
  end

  it "returns nil when request_type is an empty string" do
    expect(request_empty_type.request_type_label).to be_nil
  end

  it "returns the capitalized character when request_type is a single character" do
    expect(request_single_char_type.request_type_label).to eq('A')
  end

  it "returns the capitalized first character when request_type has multiple characters" do
    expect(request_multi_char_type.request_type_label).to eq('A')
  end
end
describe '#item_requests_uniqueness_by_item_id', :phoenix do
  let(:request) { build(:request, item_requests: item_requests) }

  context 'when all item_ids are unique' do
    let(:item_requests) do
      [
        Partners::ItemRequest.new(item_id: 1, quantity: 5),
        Partners::ItemRequest.new(item_id: 2, quantity: 10)
      ]
    end

    it 'does not add errors to request' do
      request.item_requests_uniqueness_by_item_id
      expect(request.errors[:item_requests]).to be_empty
    end
  end

  context 'when there are duplicate item_ids' do
    let(:item_requests) do
      [
        Partners::ItemRequest.new(item_id: 1, quantity: 5),
        Partners::ItemRequest.new(item_id: 1, quantity: 10)
      ]
    end

    it 'adds an error for duplicate item_ids' do
      request.item_requests_uniqueness_by_item_id
      expect(request.errors[:item_requests]).to include('should have unique item_ids')
    end
  end

  context 'when item_requests is empty' do
    let(:item_requests) { [] }

    it 'does not add errors to request' do
      request.item_requests_uniqueness_by_item_id
      expect(request.errors[:item_requests]).to be_empty
    end
  end
end
describe '#sanitize_items_data', :phoenix do
  let(:request) { build(:request, request_items: request_items) }

  context 'when request_items is nil' do
    let(:request_items) { nil }

    it 'does nothing if request_items is nil' do
      expect { request.sanitize_items_data }.not_to change { request.request_items }
    end
  end

  context 'when request_items has not changed' do
    let(:request_items) { [{ 'item_id' => 1, 'quantity' => 5 }] }

    before do
      allow(request).to receive(:request_items_changed?).and_return(false)
    end

    it 'does nothing if request_items has not changed' do
      expect { request.sanitize_items_data }.not_to change { request.request_items }
    end
  end

  describe 'when request_items is present and has changed' do
    let(:request_items) { [{ 'item_id' => '1', 'quantity' => '5' }, { 'item_id' => nil, 'quantity' => nil }] }

    before do
      allow(request).to receive(:request_items_changed?).and_return(true)
    end

    it 'converts item_id to integer' do
      request.sanitize_items_data
      expect(request.request_items.first['item_id']).to eq(1)
    end

    it 'converts quantity to integer' do
      request.sanitize_items_data
      expect(request.request_items.first['quantity']).to eq(5)
    end

    it 'handles items with nil item_id gracefully' do
      request.sanitize_items_data
      expect(request.request_items.last['item_id']).to be_nil
    end

    it 'handles items with nil quantity gracefully' do
      request.sanitize_items_data
      expect(request.request_items.last['quantity']).to be_nil
    end

    context 'when request_items is an empty array' do
      let(:request_items) { [] }

      it 'handles an empty request_items array' do
        expect { request.sanitize_items_data }.not_to change { request.request_items }
      end
    end
  end
end
describe "#not_completely_empty", :phoenix do
  let(:request_with_no_comments_or_item_requests) { build(:request, comments: nil, item_requests: []) }
  let(:request_with_comments) { build(:request, comments: "Some comment", item_requests: []) }
  let(:request_with_item_requests) { build(:request, comments: nil, item_requests: [ItemRequest.new]) }
  let(:request_with_comments_and_item_requests) { build(:request, comments: "Some comment", item_requests: [ItemRequest.new]) }

  it "adds an error when both comments and item_requests are blank" do
    request_with_no_comments_or_item_requests.not_completely_empty
    expect(request_with_no_comments_or_item_requests.errors[:base]).to include("completely empty request")
  end

  it "does not add an error when comments are present and item_requests are blank" do
    request_with_comments.not_completely_empty
    expect(request_with_comments.errors[:base]).to be_empty
  end

  it "does not add an error when comments are blank and item_requests are present" do
    request_with_item_requests.not_completely_empty
    expect(request_with_item_requests.errors[:base]).to be_empty
  end

  it "does not add an error when both comments and item_requests are present" do
    request_with_comments_and_item_requests.not_completely_empty
    expect(request_with_comments_and_item_requests.errors[:base]).to be_empty
  end
end
end
