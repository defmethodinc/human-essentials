
require "rails_helper"

RSpec.describe ProductDriveParticipant do
describe '#volume', :phoenix do
  let(:donation_with_no_line_items) { Donation.create(line_items: []) }
  let(:donation_with_line_items) do
    Donation.create(line_items: [LineItem.create(total: 10), LineItem.create(total: 20)])
  end
  let(:donation_with_mixed_line_items) do
    [Donation.create(line_items: []), Donation.create(line_items: [LineItem.create(total: 15)])]
  end

  it 'returns zero when there are no donations' do
    participant = ProductDriveParticipant.new(donations: [])
    expect(participant.volume).to eq(0)
  end

  it 'returns zero when a single donation has no line items' do
    participant = ProductDriveParticipant.new(donations: [donation_with_no_line_items])
    expect(participant.volume).to eq(0)
  end

  it 'calculates total for a single donation with line items' do
    participant = ProductDriveParticipant.new(donations: [donation_with_line_items])
    expect(participant.volume).to eq(30)
  end

  it 'calculates total for multiple donations with line items' do
    participant = ProductDriveParticipant.new(donations: [donation_with_line_items, donation_with_line_items])
    expect(participant.volume).to eq(60)
  end

  it 'calculates total for mixed donations with and without line items' do
    participant = ProductDriveParticipant.new(donations: donation_with_mixed_line_items)
    expect(participant.volume).to eq(15)
  end
end
describe "#volume_by_product_drive", :phoenix do
  let(:product_drive_participant) { create(:product_drive_participant) }
  let(:product_drive_id) { 1 }

  it "calculates total volume for a valid product drive ID" do
    donation1 = create(:donation, product_drive_id: product_drive_id, product_drive_participant: product_drive_participant)
    donation2 = create(:donation, product_drive_id: product_drive_id, product_drive_participant: product_drive_participant)
    create(:line_item, donation: donation1, total: 10)
    create(:line_item, donation: donation2, total: 20)

    expect(product_drive_participant.volume_by_product_drive(product_drive_id)).to eq(30)
  end

  it "returns zero for an invalid product drive ID" do
    expect(product_drive_participant.volume_by_product_drive(-1)).to eq(0)
  end

  it "returns zero when there are no donations for the given product drive ID" do
    expect(product_drive_participant.volume_by_product_drive(product_drive_id)).to eq(0)
  end

  it "sums up line items for multiple donations correctly" do
    donation1 = create(:donation, product_drive_id: product_drive_id, product_drive_participant: product_drive_participant)
    donation2 = create(:donation, product_drive_id: product_drive_id, product_drive_participant: product_drive_participant)
    create(:line_item, donation: donation1, total: 5)
    create(:line_item, donation: donation2, total: 15)

    expect(product_drive_participant.volume_by_product_drive(product_drive_id)).to eq(20)
  end

  describe "edge cases" do
    it "handles very large numbers correctly" do
      donation = create(:donation, product_drive_id: product_drive_id, product_drive_participant: product_drive_participant)
      create(:line_item, donation: donation, total: 10**9)

      expect(product_drive_participant.volume_by_product_drive(product_drive_id)).to eq(10**9)
    end

    it "handles empty line items correctly" do
      donation = create(:donation, product_drive_id: product_drive_id, product_drive_participant: product_drive_participant)
      create(:line_item, donation: donation, total: 0)

      expect(product_drive_participant.volume_by_product_drive(product_drive_id)).to eq(0)
    end
  end
end
describe '#donation_source_view', :phoenix do
  let(:product_drive_participant_with_contact_name) { ProductDriveParticipant.new(contact_name: 'John Doe') }
  let(:product_drive_participant_without_contact_name) { ProductDriveParticipant.new(contact_name: nil) }

  it 'returns nil when contact_name is blank' do
    expect(product_drive_participant_without_contact_name.donation_source_view).to be_nil
  end

  it 'returns contact_name with (participant) when contact_name is present' do
    expect(product_drive_participant_with_contact_name.donation_source_view).to eq('John Doe (participant)')
  end
end
end
