
require "rails_helper"

RSpec.describe BarcodeItem do
describe '#to_h', :phoenix do
  let(:barcode_item) { build(:barcode_item, barcodeable_id: barcodeable_id, barcodeable_type: barcodeable_type, quantity: quantity) }
  let(:barcodeable_id) { 1 }
  let(:barcodeable_type) { 'Item' }
  let(:quantity) { 10 }

  it 'returns a hash with the correct keys and values' do
    expect(barcode_item.to_h).to eq({ barcodeable_id: 1, barcodeable_type: 'Item', quantity: 10 })
  end

  describe 'when barcodeable_id is nil' do
    let(:barcodeable_id) { nil }

    it 'returns a hash with nil barcodeable_id' do
      expect(barcode_item.to_h).to eq({ barcodeable_id: nil, barcodeable_type: 'Item', quantity: 10 })
    end
  end

  describe 'when barcodeable_type is nil' do
    let(:barcodeable_type) { nil }

    it 'returns a hash with nil barcodeable_type' do
      expect(barcode_item.to_h).to eq({ barcodeable_id: 1, barcodeable_type: nil, quantity: 10 })
    end
  end

  describe 'when quantity is nil' do
    let(:quantity) { nil }

    it 'returns a hash with nil quantity' do
      expect(barcode_item.to_h).to eq({ barcodeable_id: 1, barcodeable_type: 'Item', quantity: nil })
    end
  end

  describe 'when attributes have non-standard values' do
    let(:barcodeable_id) { 999 }
    let(:barcodeable_type) { 'NonStandardType' }
    let(:quantity) { 999 }

    it 'returns a hash with non-standard barcodeable_id' do
      expect(barcode_item.to_h).to eq({ barcodeable_id: 999, barcodeable_type: 'NonStandardType', quantity: 999 })
    end

    it 'returns a hash with non-standard barcodeable_type' do
      expect(barcode_item.to_h).to eq({ barcodeable_id: 999, barcodeable_type: 'NonStandardType', quantity: 999 })
    end

    it 'returns a hash with non-standard quantity' do
      expect(barcode_item.to_h).to eq({ barcodeable_id: 999, barcodeable_type: 'NonStandardType', quantity: 999 })
    end
  end
end
describe '.csv_export_headers', :phoenix do
  it 'returns an array with the correct headers' do
    expect(BarcodeItem.csv_export_headers).to eq(["Item Type", "Quantity in the Box", "Barcode"])
  end
end
describe '#csv_export_attributes', :phoenix do
  let(:barcodeable_with_name) { create(:item, name: 'Test Item') }
  let(:barcode_item_with_name) { build(:barcode_item, barcodeable: barcodeable_with_name, quantity: 10, value: '100') }
  let(:barcode_item_nil_barcodeable) { build(:barcode_item, barcodeable: nil, quantity: 10, value: '100') }
  let(:barcode_item_zero_quantity) { build(:barcode_item, barcodeable: barcodeable_with_name, quantity: 0, value: '100') }
  let(:barcode_item_nil_value) { build(:barcode_item, barcodeable: barcodeable_with_name, quantity: 10, value: nil) }

  it 'returns an array with barcodeable name, quantity, and value' do
    expect(barcode_item_with_name.csv_export_attributes).to eq(['Test Item', 10, '100'])
  end

  describe 'when barcodeable is nil' do
    it 'returns an array with nil for barcodeable name' do
      expect(barcode_item_nil_barcodeable.csv_export_attributes).to eq([nil, 10, '100'])
    end
  end

  describe 'when barcodeable has a name' do
    it 'includes the name in the array' do
      expect(barcode_item_with_name.csv_export_attributes).to include('Test Item')
    end
  end

  describe 'when quantity is zero' do
    it 'includes zero quantity in the array' do
      expect(barcode_item_zero_quantity.csv_export_attributes).to eq(['Test Item', 0, '100'])
    end
  end

  describe 'when value is nil' do
    it 'returns an array with nil for value' do
      expect(barcode_item_nil_value.csv_export_attributes).to eq(['Test Item', 10, nil])
    end
  end
end
describe '#global?', :phoenix do
  let(:global_barcode_item) { build(:barcode_item, barcodeable_type: 'BaseItem') }
  let(:non_global_barcode_item) { build(:barcode_item, barcodeable_type: 'NonBaseItem') }

  it 'returns true when barcodeable_type is BaseItem' do
    expect(global_barcode_item.global?).to be true
  end

  it 'returns false when barcodeable_type is not BaseItem' do
    expect(non_global_barcode_item.global?).to be false
  end
end
describe "#unique_barcode_value", :phoenix do
  let(:organization) { create(:organization) }
  let(:base_item) { create(:base_item) }

  context "when the barcode is global" do
    let(:global_barcode_item) { build(:global_barcode_item, value: "123456789012", barcodeable: base_item) }

    it "adds an error if the barcode value already exists for a different BarcodeItem with barcodeable_type as 'BaseItem'" do
      create(:global_barcode_item, value: "123456789012", barcodeable: base_item)
      global_barcode_item.valid?
      expect(global_barcode_item.errors[:value]).to include("That barcode value already exists")
    end

    it "does not add an error if the barcode value does not exist for any other BarcodeItem" do
      global_barcode_item.valid?
      expect(global_barcode_item.errors[:value]).to be_empty
    end
  end

  context "when the barcode is not global" do
    let(:barcode_item) { build(:barcode_item, value: "123456789012", organization: organization) }

    it "adds an error if the barcode value already exists for a different BarcodeItem within the same organization" do
      create(:barcode_item, value: "123456789012", organization: organization)
      barcode_item.valid?
      expect(barcode_item.errors[:value]).to include("That barcode value already exists")
    end

    it "does not add an error if the barcode value does not exist for any other BarcodeItem within the same organization" do
      barcode_item.valid?
      expect(barcode_item.errors[:value]).to be_empty
    end
  end
end
end
