
require "rails_helper"

RSpec.describe AnnualReport do
describe '#each_report', :phoenix do
  let(:annual_report) { AnnualReport.new(all_reports: all_reports) }

  context 'when all_reports is empty' do
    let(:all_reports) { [] }

    it 'does not yield anything' do
      expect { |b| annual_report.each_report(&b) }.not_to yield_control
    end
  end

  context 'when all_reports has one report' do
    let(:all_reports) { [{'name' => 'Report 1', 'entries' => ['entry1', 'entry2']}] }

    it 'yields once with correct name and entries' do
      expect { |b| annual_report.each_report(&b) }.to yield_with_args('Report 1', ['entry1', 'entry2'])
    end
  end

  context 'when all_reports has multiple reports' do
    let(:all_reports) { [{'name' => 'Report 1', 'entries' => ['entry1', 'entry2']}, {'name' => 'Report 2', 'entries' => ['entry3', 'entry4']}] }

    it 'yields for each report with correct name and entries' do
      expect { |b| annual_report.each_report(&b) }.to yield_successive_args(['Report 1', ['entry1', 'entry2']], ['Report 2', ['entry3', 'entry4']])
    end
  end

  context 'when a report is missing the name key' do
    let(:all_reports) { [{'entries' => ['entry1', 'entry2']}] }

    it 'yields with nil for missing name key' do
      expect { |b| annual_report.each_report(&b) }.to yield_with_args(nil, ['entry1', 'entry2'])
    end
  end

  context 'when a report is missing the entries key' do
    let(:all_reports) { [{'name' => 'Report 1'}] }

    it 'yields with nil for missing entries key' do
      expect { |b| annual_report.each_report(&b) }.to yield_with_args('Report 1', nil)
    end
  end
end
end
