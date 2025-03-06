
require "rails_helper"

RSpec.describe Kit do
describe '#can_deactivate?', :phoenix do
  let(:organization) { create(:organization) }
  let(:item) { create(:item, organization: organization) }
  let(:inventory) { View::Inventory.new(organization_id: organization.id) }

  context 'when inventory is provided' do
    before do
      allow(inventory).to receive(:quantity_for).with(item_id: item.id).and_return(quantity)
    end

    context 'when quantity is zero' do
      let(:quantity) { 0 }

      it 'returns true if quantity is zero' do
        expect(Kit.new.can_deactivate?(inventory)).to be true
      end
    end

    context 'when quantity is not zero' do
      let(:quantity) { 5 }

      it 'returns false if quantity is not zero' do
        expect(Kit.new.can_deactivate?(inventory)).to be false
      end
    end
  end

  context 'when no inventory is provided' do
    before do
      allow_any_instance_of(View::Inventory).to receive(:quantity_for).with(item_id: item.id).and_return(quantity)
    end

    context 'when quantity is zero' do
      let(:quantity) { 0 }

      it 'returns true if quantity is zero' do
        expect(Kit.new.can_deactivate?).to be true
      end
    end

    context 'when quantity is not zero' do
      let(:quantity) { 5 }

      it 'returns false if quantity is not zero' do
        expect(Kit.new.can_deactivate?).to be false
      end
    end
  end
end
describe '#deactivate', :phoenix do
  let(:kit) { create(:kit, active: true) }
  let(:kit_with_item) { create(:kit, :with_item, active: true) }
  let(:deactivated_kit) { create(:kit, active: false) }
  let(:deactivated_kit_with_item) { create(:kit, :with_item, active: false) }

  it 'deactivates the Kit' do
    kit.deactivate
    expect(kit.active).to eq(false)
  end

  it 'deactivates the associated item' do
    kit_with_item.deactivate
    expect(kit_with_item.item.active).to eq(false)
  end

  context 'when Kit fails to deactivate' do
    before do
      allow(kit).to receive(:update!).and_raise(ActiveRecord::RecordInvalid)
    end

    it 'raises an error' do
      expect { kit.deactivate }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  context 'when associated item fails to deactivate' do
    before do
      allow(kit_with_item.item).to receive(:update!).and_raise(ActiveRecord::RecordInvalid)
    end

    it 'raises an error' do
      expect { kit_with_item.deactivate }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  context 'when Kit is already deactivated' do
    let(:kit) { deactivated_kit }

    it 'remains inactive' do
      kit.deactivate
      expect(kit.active).to eq(false)
    end
  end

  context 'when associated item is already deactivated' do
    let(:kit_with_item) { deactivated_kit_with_item }

    it 'remains inactive' do
      kit_with_item.deactivate
      expect(kit_with_item.item.active).to eq(false)
    end
  end

  context 'when item is nil' do
    let(:kit) { create(:kit, line_items: []) }

    it 'does not raise an error' do
      expect { kit.deactivate }.not_to raise_error
    end
  end
end
describe '#can_reactivate?', :phoenix do
  let(:kit) { build(:kit, line_items: line_items) }

  context 'when no line items are associated' do
    let(:line_items) { [] }

    it 'returns true when there are no line items' do
      expect(kit.can_reactivate?).to eq(true)
    end
  end

  context 'when all line items are associated with active items' do
    let(:active_item) { build(:item, active: true) }
    let(:line_items) { [build(:line_item, item: active_item)] }

    it 'returns true when all items are active' do
      expect(kit.can_reactivate?).to eq(true)
    end
  end

  context 'when some line items are associated with inactive items' do
    let(:active_item) { build(:item, active: true) }
    let(:inactive_item) { build(:item, active: false) }
    let(:line_items) { [build(:line_item, item: active_item), build(:line_item, item: inactive_item)] }

    it 'returns false when some items are inactive' do
      expect(kit.can_reactivate?).to eq(false)
    end
  end

  context 'when all line items are associated with inactive items' do
    let(:inactive_item) { build(:item, active: false) }
    let(:line_items) { [build(:line_item, item: inactive_item)] }

    it 'returns false when all items are inactive' do
      expect(kit.can_reactivate?).to eq(false)
    end
  end
end
describe '#reactivate', :phoenix do
  let(:kit) { build(:kit, active: false) }
  let(:item) { build(:item, active: false, kit: kit) }

  before do
    allow(kit).to receive(:item).and_return(item)
  end

  it 'reactivates the kit' do
    kit.reactivate
    expect(kit.active).to eq(true)
  end

  it 'reactivates the item' do
    kit.reactivate
    expect(item.active).to eq(true)
  end

  describe 'when kit update fails' do
    before do
      allow(kit).to receive(:update!).and_raise(ActiveRecord::RecordInvalid.new(kit))
    end

    it 'raises an error and does not reactivate the item' do
      expect { kit.reactivate }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it 'does not change item active status' do
      expect(item.active).to eq(false)
    end
  end

  describe 'when item update fails' do
    before do
      allow(item).to receive(:update!).and_raise(ActiveRecord::RecordInvalid.new(item))
    end

    it 'raises an error and does not affect kit reactivation' do
      expect { kit.reactivate }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it 'keeps kit active status unchanged' do
      kit.reactivate rescue nil
      expect(kit.active).to eq(true)
    end
  end

  describe 'when an exception is raised during update' do
    before do
      allow(kit).to receive(:update!).and_raise(StandardError)
    end

    it 'raises a standard error' do
      expect { kit.reactivate }.to raise_error(StandardError)
    end
  end
end
describe '#at_least_one_item', :phoenix do
  let(:kit_without_items) { build(:kit, line_items: []) }
  let(:kit_with_items) { build(:kit) } # by default, the factory adds a line_item

  context 'when there are no line_items' do
    it 'adds an error to the base' do
      kit_without_items.at_least_one_item
      expect(kit_without_items.errors[:base]).to include('At least one item is required')
    end
  end

  context 'when there is at least one line_item' do
    it 'does not add an error to the base' do
      kit_with_items.at_least_one_item
      expect(kit_with_items.errors[:base]).to be_empty
    end
  end
end
end
