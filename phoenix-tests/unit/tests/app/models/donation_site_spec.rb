
require "rails_helper"

RSpec.describe DonationSite do
describe '#import_csv', :phoenix do
  let(:organization) { create(:organization) }
  let(:valid_csv) { [ { 'name' => 'Site 1', 'address' => '123 Main St', 'contact_name' => 'John Doe', 'email' => 'john@example.com', 'phone' => '555-1234' }, { 'name' => 'Site 2', 'address' => '456 Elm St', 'contact_name' => 'Jane Doe', 'email' => 'jane@example.com', 'phone' => '555-5678' } ] }
  let(:invalid_csv) { [ { 'name' => '', 'address' => '', 'contact_name' => '', 'email' => '', 'phone' => '' } ] }
  let(:empty_csv) { [] }

  it 'increases DonationSite count by 2 when valid CSV is imported' do
    expect { DonationSite.import_csv(valid_csv, organization.id) }.to change { DonationSite.count }.by(2)
  end

  it 'raises an error when importing invalid CSV data' do
    expect { DonationSite.import_csv(invalid_csv, organization.id) }.to raise_error(ActiveRecord::RecordInvalid)
  end

  it 'does not change DonationSite count when CSV is empty' do
    expect { DonationSite.import_csv(empty_csv, organization.id) }.not_to change { DonationSite.count }
  end
end
describe ".csv_export_headers", :phoenix do
  it "returns an array with 'Name' as the first header" do
    expect(DonationSite.csv_export_headers.first).to eq("Name")
  end

  it "returns an array with 'Address' as the second header" do
    expect(DonationSite.csv_export_headers[1]).to eq("Address")
  end

  it "returns an array with 'Contact Name' as the third header" do
    expect(DonationSite.csv_export_headers[2]).to eq("Contact Name")
  end

  it "returns an array with 'Email' as the fourth header" do
    expect(DonationSite.csv_export_headers[3]).to eq("Email")
  end

  it "returns an array with 'Phone' as the fifth header" do
    expect(DonationSite.csv_export_headers[4]).to eq("Phone")
  end

  it "returns an array with exactly five headers" do
    expect(DonationSite.csv_export_headers.size).to eq(5)
  end
end
describe '#csv_export_attributes', :phoenix do
  let(:donation_site) { build(:donation_site, name: 'Charity Hub', address: '123 Charity Lane', contact_name: 'John Doe', email: 'contact@charityhub.org', phone: '123-456-7890') }

  it 'returns an array of all attributes' do
    expect(donation_site.csv_export_attributes).to eq(['Charity Hub', '123 Charity Lane', 'John Doe', 'contact@charityhub.org', '123-456-7890'])
  end

  context 'when contact_name is blank' do
    let(:donation_site) { build(:donation_site, contact_name: '') }

    it 'returns an array with blank contact_name' do
      expect(donation_site.csv_export_attributes).to eq(['Charity Hub', '123 Charity Lane', '', 'contact@charityhub.org', '123-456-7890'])
    end
  end

  context 'when email is blank' do
    let(:donation_site) { build(:donation_site, email: '') }

    it 'returns an array with blank email' do
      expect(donation_site.csv_export_attributes).to eq(['Charity Hub', '123 Charity Lane', 'John Doe', '', '123-456-7890'])
    end
  end

  context 'when phone is blank' do
    let(:donation_site) { build(:donation_site, phone: '') }

    it 'returns an array with blank phone' do
      expect(donation_site.csv_export_attributes).to eq(['Charity Hub', '123 Charity Lane', 'John Doe', 'contact@charityhub.org', ''])
    end
  end
end
describe '#deactivate!', :phoenix do
  let(:donation_site) { create(:donation_site, active: true) }

  it 'deactivates the donation site by setting active to false' do
    donation_site.deactivate!
    expect(donation_site.active).to be_falsey
  end

  context 'when update fails' do
    before do
      allow(donation_site).to receive(:update!).and_raise(ActiveRecord::RecordInvalid)
    end

    it 'raises ActiveRecord::RecordInvalid error' do
      expect { donation_site.deactivate! }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end
end
end
