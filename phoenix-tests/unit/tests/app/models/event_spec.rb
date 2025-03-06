
require "rails_helper"

RSpec.describe Event do
describe "#types_for_select", :phoenix do
  let(:descendant_class_1) { Class.new(Event) { def self.name; 'MusicEvent'; end } }
  let(:descendant_class_2) { Class.new(Event) { def self.name; 'ArtEvent'; end } }
  let(:unexpected_class) { Class.new(Event) { def self.name; 'UnexpectedPattern'; end } }

  before do
    stub_const('MusicEvent', descendant_class_1)
    stub_const('ArtEvent', descendant_class_2)
    stub_const('UnexpectedPattern', unexpected_class)
  end

  it "returns an array of OpenStruct objects with correct size" do
    result = Event.types_for_select
    expect(result.size).to eq(2)
  end

  it "contains correct class values" do
    result = Event.types_for_select
    expect(result.map(&:value)).to contain_exactly('MusicEvent', 'ArtEvent')
  end

  it "removes 'Event' from class name and titleizes it for the name attribute" do
    result = Event.types_for_select
    expect(result.map(&:name)).to contain_exactly('Music', 'Art')
  end

  it "sorts the OpenStruct objects by name attribute" do
    result = Event.types_for_select
    expect(result.map(&:name)).to eq(['Art', 'Music'])
  end

  context "when there are no descendants" do
    before do
      allow(Event).to receive(:descendants).and_return([])
    end

    it "returns an empty array" do
      result = Event.types_for_select
      expect(result).to eq([])
    end
  end

  context "when descendant class names do not follow the expected pattern" do
    before do
      allow(Event).to receive(:descendants).and_return([unexpected_class])
    end

    it "handles unexpected class name patterns gracefully" do
      result = Event.types_for_select
      expect(result.map(&:name)).to contain_exactly('Unexpected Pattern')
    end
  end
end
describe '#most_recent_snapshot', :phoenix do
  let(:organization_id) { 1 }

  let!(:snapshot_event) { Event.create(type: 'SnapshotEvent', organization_id: organization_id, event_time: 2.days.ago, updated_at: 2.days.ago) }
  let!(:non_snapshot_event) { Event.create(type: 'NonSnapshotEvent', organization_id: organization_id, event_time: 3.days.ago, updated_at: 1.day.ago) }

  it 'retrieves the most recent snapshot event when it exists' do
    result = Event.most_recent_snapshot(organization_id)
    expect(result).to eq(snapshot_event)
  end

  it 'returns nil when there are no snapshot events for the organization' do
    Event.where(type: 'SnapshotEvent', organization_id: organization_id).destroy_all
    result = Event.most_recent_snapshot(organization_id)
    expect(result).to be_nil
  end

  it 'returns the most recent snapshot event when non-snapshot events have earlier event times but later update times' do
    result = Event.most_recent_snapshot(organization_id)
    expect(result).to eq(snapshot_event)
  end

  it 'returns the most recent snapshot event when multiple snapshot events exist' do
    recent_snapshot_event = Event.create(type: 'SnapshotEvent', organization_id: organization_id, event_time: 1.day.ago, updated_at: 1.day.ago)
    result = Event.most_recent_snapshot(organization_id)
    expect(result).to eq(recent_snapshot_event)
  end

  it 'returns one of the snapshot events when multiple have the same event time' do
    another_snapshot_event = Event.create(type: 'SnapshotEvent', organization_id: organization_id, event_time: 2.days.ago, updated_at: 2.days.ago)
    result = Event.most_recent_snapshot(organization_id)
    expect([snapshot_event, another_snapshot_event]).to include(result)
  end
end
describe '#validate_inventory', :phoenix do
  let(:organization) { create(:organization) }
  let(:item) { create(:item, organization: organization) }
  let(:storage_location) { create(:storage_location, organization: organization) }
  let(:event) { Event.create(organization: organization) }

  it 'handles successful inventory validation' do
    allow(InventoryAggregate).to receive(:inventory_for).and_return(true)
    expect { event.validate_inventory }.not_to raise_error
  end

  context 'when InventoryError is raised' do
    let(:inventory_error) { InventoryError.new('Error message', item_id: item.id, storage_location_id: storage_location.id, event: event) }

    before do
      allow(InventoryAggregate).to receive(:inventory_for).and_raise(inventory_error)
    end

    it 'raises error with item name when item is found' do
      expect { event.validate_inventory }.to raise_error(InventoryError, /for #{item.name}/)
    end

    it 'raises error with item ID when item is not found' do
      inventory_error.item_id = nil
      expect { event.validate_inventory }.to raise_error(InventoryError, /for Item ID/)
    end

    it 'raises error with storage location name when storage location is found' do
      expect { event.validate_inventory }.to raise_error(InventoryError, /in #{storage_location.name}/)
    end

    it 'raises error with storage location ID when storage location is not found' do
      inventory_error.storage_location_id = nil
      expect { event.validate_inventory }.to raise_error(InventoryError, /in Storage Location ID/)
    end

    context 'when error event matches current event' do
      it 'raises error with original message' do
        expect { event.validate_inventory }.to raise_error(InventoryError, /Error message/)
      end
    end

    context 'when error event does not match current event' do
      let(:other_event) { Event.create(organization: organization) }

      before do
        inventory_error.event = other_event
      end

      it 'raises error with re-run event message' do
        expect { event.validate_inventory }.to raise_error(InventoryError, /Error occurred when re-running events/)
      end
    end
  end
end
end
