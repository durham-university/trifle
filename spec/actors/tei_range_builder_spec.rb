require 'rails_helper'

RSpec.describe Trifle::TEIRangeBuilderActor do
  
  let(:manifest) { FactoryGirl.build(:iiifmanifest) }
  let(:range) { FactoryGirl.create(:iiifrange, :with_manifest, :with_canvases, :with_sub_range) }
  let(:user) { nil }
  let(:options) { {} }
  let(:actor) { Trifle::TEIRangeBuilderActor.new(manifest, user, options) }

  let(:mock_api_object) { 
    double('api object').tap do |api_object|
      allow(api_object).to receive(:xml_record).and_return(mock_xml_record)
    end
  }
  let(:mock_xml_record) { 
    double('xml record').tap do |xml_record| 
      allow(xml_record).to receive(:child_items).and_return([
        double('child1', title: 'section (A)', locus: 'f. 1r - 5r ', child_items:[
          double('child1_1', title: '1. test item', locus: 'f.1 r- 3r', child_items:[]),
          double('child1_2', title: '2. another item', locus: 'f.  3r- 5 r', child_items:[]),
        ]),
        double('child2', title: 'section (B)', locus: '5v - 7 v', child_items:[
          double('child2_1', title: '3. test item', locus: 'f5 v- 6r', child_items:[]),
          double('child2_2', title: '4. another item', locus: ' 6v - f.7v', child_items:[]),
        ]),
      ])
    end
  }
  before {
    allow(manifest).to receive(:source_type).and_return('schmit')
    allow(manifest).to receive(:source_identifier).and_return('ark:/12345/12345')
    allow(Schmit::API::Catalogue).to receive(:try_find).with('ark:/12345/12345').and_return(mock_api_object)
  }
  
  let(:range_items) { [
    Trifle::TEIRangeBuilderActor::ParsedRangeEntry.new(title: 'section (A)', from: 'f.1r', to: 'f.2r', sub_entries: [
      Trifle::TEIRangeBuilderActor::ParsedRangeEntry.new(title: '1. test item', from: 'f.1r', to: 'f.1r', sub_entries: []),
      Trifle::TEIRangeBuilderActor::ParsedRangeEntry.new(title: '2. other item', from: 'f.1v', to: 'f.2r', sub_entries: [])
    ]),
    Trifle::TEIRangeBuilderActor::ParsedRangeEntry.new(title: 'section (B)', from: 'f.2v', to: 'f.4v', sub_entries: [
      Trifle::TEIRangeBuilderActor::ParsedRangeEntry.new(title: '3. test item', from: 'f.2v', to: 'f.3r', sub_entries: []),
      Trifle::TEIRangeBuilderActor::ParsedRangeEntry.new(title: '4. other item', from: 'f.3r', to: 'f.4v', sub_entries: [])
    ])
  ] }
  

  describe "#build_range" do
    it "calls other methods" do
      expect(actor).to receive(:parse_range).and_return(range_items)
      expect(actor).to receive(:match_parsed).with(range_items)
      expect(actor).to receive(:build_new_range).with(range_items).and_return('return value')
      expect(actor.build_range).to eql('return value')
    end
  end
  
  describe "#clear_ranges" do
    let(:manifest) { range.manifest }
    it "destroys ranges" do
      actor.clear_ranges
      expect(manifest.reload.ranges).to be_empty
    end
  end
  
  describe "#build_new_range" do
    before {
      (1..4).map do |n| ["f.#{n}r","f.#{n}v"] end .flatten .each do |folio|
        manifest.ordered_members << Trifle::IIIFImage.create(title: folio)
      end
      actor.match_parsed(range_items)
    }
    it "builds IIIFRange" do
      range = actor.build_new_range(range_items)
      expect(manifest.ranges).to include(range)
      expect(range).to be_a(Trifle::IIIFRange)
      expect(range.sub_ranges.count).to eql(2)
      expect(range.sub_ranges[0].title).to eql('section (A)')
      expect(range.sub_ranges[0].canvases.count).to eql(3)
      expect(range.sub_ranges[0].canvases.to_a).to all( be_a(Trifle::IIIFImage) )
      expect(range.sub_ranges[0].sub_ranges.count).to eql(2)
      expect(range.sub_ranges[0].sub_ranges[0].title).to eql('1. test item')
      expect(range.sub_ranges[0].sub_ranges[0].canvases.count).to eql(1)
      expect(range.sub_ranges[0].sub_ranges[1].title).to eql('2. other item')
      expect(range.sub_ranges[0].sub_ranges[1].canvases.count).to eql(2)
    end
  end
  
  describe "#match_parsed" do
    before {
      (1..4).map do |n| ["f.#{n}r","f.#{n}v"] end .flatten .each do |folio|
        manifest.ordered_members << Trifle::IIIFImage.create(title: folio)
      end
    }
    it "matches IIIFImages" do
      actor.match_parsed(range_items)
      expect(range_items[0].refs).to all( be_a(Trifle::IIIFImage) )
      expect(range_items[0].refs.map(&:title)).to eql(['f.1r','f.1v','f.2r'])
      expect(range_items[0].sub_entries[0].refs).to all( be_a(Trifle::IIIFImage) )
      expect(range_items[0].sub_entries[0].refs.map(&:title)).to eql(['f.1r'])
      expect(range_items[0].sub_entries[1].refs.map(&:title)).to eql(['f.1v','f.2r'])
    end
  end
  
  describe "#tei_record" do
    it "returns the tei record" do
      expect(actor.tei_record).to eql(mock_xml_record)
    end
  end
  
  describe "#normalise_foliation" do
    it "normalises foliation" do
      expect(actor.normalise_foliation('f.2r')).to eql('f.2r')
      expect(actor.normalise_foliation('f2v')).to eql('f.2v')
      expect(actor.normalise_foliation('2V')).to eql('f.2v')
      expect(actor.normalise_foliation('f 23 R  ')).to eql('f.23r')
      expect(actor.normalise_foliation(' f. 112 r ')).to eql('f.112r')
      expect(actor.normalise_foliation(' something else ')).to eql('something else')
    end
  end
  
  describe "#parse_range" do
    it "parses range structure" do
      ranges = actor.parse_range
      expect(ranges.count).to eql(2)
      expect(ranges[0].title).to eql('section (A)')
      expect(ranges[0].from).to eql('f.1r')
      expect(ranges[0].to).to eql('f.5r')
      expect(ranges[0].sub_entries.count).to eql(2)
      expect(ranges[0].sub_entries[0].title).to eql('1. test item')
      expect(ranges[0].sub_entries[0].from).to eql('f.1r')
      expect(ranges[0].sub_entries[0].to).to eql('f.3r')
      expect(ranges[0].sub_entries[1].title).to eql('2. another item')
      expect(ranges[1].title).to eql('section (B)')
      expect(ranges[1].from).to eql('f.5v')
      expect(ranges[1].to).to eql('f.7v')
      expect(ranges[1].sub_entries.count).to eql(2)
      expect(ranges[1].sub_entries[0].title).to eql('3. test item')
      expect(ranges[1].sub_entries[1].title).to eql('4. another item')
    end
  end

end