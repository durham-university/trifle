require 'rails_helper'
require 'marc'

RSpec.describe Trifle::MillenniumActor do
  before { allow(Trifle::IIIFManifest).to receive(:ark_naan).and_return('12345') }
  let(:user) {nil}
  let(:options) { { } }
  let(:manifest) { FactoryGirl.build(:iiifmanifest) }
  let(:actor) { Trifle::MillenniumActor.new(manifest,user,options) }
  before {
    allow(actor).to receive(:default_connection_params).and_return({})
    allow(actor).to receive(:default_remote_path).and_return('/tmp')
    expect(actor).not_to receive(:write_package)
    expect(actor).not_to receive(:send_or_copy_file)
  }

  describe "#upload_package" do
    it "calls millennium_package" do
      expect(actor).to receive(:millennium_package).and_return([])
      actor.upload_package
    end
  end

  describe "#upload_everything" do
    let(:manifest) { nil }
    let!(:manifest1) { FactoryGirl.create(:iiifmanifest, source_record: 'millennium:testid1') }
    let!(:manifest2) { FactoryGirl.create(:iiifmanifest, source_record: 'millennium:testid2#fragment1') }
    let!(:manifest3) { FactoryGirl.create(:iiifmanifest, source_record: 'millennium:testid1#fragment2') }
    let!(:manifest4) { FactoryGirl.create(:iiifmanifest, source_record: 'millennium:testid1') }
    let!(:manifest5) { FactoryGirl.create(:iiifmanifest, source_record: 'millennium:testid2#fragment3') }
    
    it "uploads everything with Millennium source record" do
      uploaded_objects = []
      expect(actor).to receive(:upload_package).twice do
        uploaded_objects << actor.instance_variable_get(:@model_object).source_record.split('#').first
      end

      actor.upload_everything

      expect(uploaded_objects).to match_array(['millennium:testid1','millennium:testid2'])
    end
  end

  describe "#millennium_package" do
    before {
      expect(manifest).to receive(:to_millennium_all).and_return({
        'mid1234' => [
          MARC::DataField.new('856', '4', '1',['3', 'SM3'], ['y', 'Online version'], ['u', 'http://www.example.com/trifle_link3'], ['x', 'Injected by Trifle']),
          MARC::DataField.new('856', '4', '1',['3', 'SM4'], ['y', 'Online version'], ['u', 'http://www.example.com/trifle_link4'], ['x', 'Injected by Trifle']),
          MARC::DataField.new('856', '4', '1',['8', '1\c'], ['3', 'SM1'], ['y', 'Online version'], ['u', 'http://www.example.com/trifle_link1'], ['x', 'Injected by Trifle']),
          MARC::DataField.new('533', nil, nil,['8', '1\c'], ['3', 'SM1'], ['a', 'Digital image'], ['c', 'Durham University'], ['n', 'new note'])
        ],
        'mid5678' => [ MARC::DataField.new('533', nil, nil,['a', 'Digital image'], ['n', 'another test']) ]
      })
#      expect(actor).to receive(:existing_millennium_fields).twice.and_return([
#          MARC::DataField.new('856', '4', '1',['3', 'SM3'], ['y', 'Online version'], ['u', 'http://www.example.com/trifle_link3'], ['x', 'Injected by Trifle']),
#          MARC::DataField.new('856', '4', '1',['3', 'SM5'], ['y', 'Online version'], ['u', 'http://www.example.com/trifle_link5'], ['x', 'Injected by Trifle']),
#          MARC::DataField.new('856', '4', '1',['8', '2\c'], ['3', 'SM2'], ['y', 'Online version'], ['u', 'https://n2t.durham.ac.uk/ark:/12345/t0abcdefg.html'], ['x', 'Injected by Trifle']),
#          MARC::DataField.new('856', '4', '1',['z', 'Online version'], ['u', 'http://www.example.com/preserved_link']),
#          MARC::DataField.new('533', nil, nil,['8', '2\c'], ['3', 'SM2'], ['a', 'Digital image'], ['n', 'test note']),
#          MARC::DataField.new('533', nil, nil,['a', 'Microfilm'], ['n', 'another copy']),
#          MARC::DataField.new('130', '0', nil,['8', '1\u'], ['a', 'test'], ['l', 'test']),
#          MARC::DataField.new('132', '0', nil,['8', '1\u'], ['a', 'test'], ['l', 'test'])
#        ])
    }
    it "gets all millennium records" do
#      expect(actor).to receive(:remove_old_injected_fields).twice.and_call_original
#      expect(actor).to receive(:pick_relevant_fields).twice.and_call_original
      package = actor.millennium_package.to_a
      expect(package.length).to eql(2)
      expect(package[0].path).to eql('mid1234')
      contents = package[0].content.to_s
      expect(contents).to start_with('<?xml version=\'1.0\'?>')
      expect(contents).to include('<collection')
      expect(contents).to include('</collection>') # make sure the xml writer is closed properly
#      expect(contents).not_to include('https://n2t.durham.ac.uk/ark:/12345/t0abcdefg.html')
#      expect(contents).not_to include('test note')
      expect(contents).to include('Online version')
      expect(contents).to include('new note')
#      expect(contents).to include('http://www.example.com/preserved_link')
      expect(contents).to include('http://www.example.com/trifle_link1')
      expect(contents).to include('http://www.example.com/trifle_link3')
      expect(contents).to include('http://www.example.com/trifle_link4')
#      expect(contents).not_to include('http://www.example.com/trifle_link5')
#      expect(contents).to include("<subfield code='8'>2\\c</subfield>")
#      expect(contents).not_to include("another test")
      expect(package[1].path).to eql('mid5678')
      expect(package[1].content.to_s).to include("another test")
    end
  end
  
  describe "#existing_millennium_fields" do
    let(:mock_connection) { double('mock_connection')}
    let(:millennium_id) { 'abcdefgh' }
    let(:marc_record) {
      MARC::Record.new().tap do |r|
        r.append(MARC::DataField.new('856', '4', '1',['8', '2\u'], ['z', 'Online version'], ['u', 'https://n2t.durham.ac.uk/ark:/12345/t0abcdefg.html']))
        r.append(MARC::DataField.new('533', nil, nil,['8', '2\u'], ['a', 'Digital image'], ['n', 'test note']))
        r.append(MARC::DataField.new('856', '4', '1',['8', '2\u'], ['z', 'Online version'], ['u', 'http://www.example.com']))
        r.append(MARC::DataField.new('533', nil, nil,['8', '2\u'], ['a', 'Microfilm'], ['n', 'test note']))
        r.append(MARC::DataField.new('533', nil, nil,['a', 'Microfilm'], ['n', 'another copy']))
        r.append(MARC::DataField.new('130', '0', nil,['8', '1\u'], ['a', 'test'], ['l', 'test']))
      end
    }
    before {
      expect(DurhamRails::LibrarySystems::Millennium).to receive(:connection).and_return(mock_connection)
      expect(mock_connection).to receive(:record).with(millennium_id).and_return(double('mock_record',marc_record: marc_record))
    }
    
    it "returns all existing fields" do
      existing = actor.existing_millennium_fields(millennium_id)
      expect(existing.map(&:to_s)).to eql([
        '856 41 $8 2\u $z Online version $u https://n2t.durham.ac.uk/ark:/12345/t0abcdefg.html ',
        '533    $8 2\u $a Digital image $n test note ',
        '856 41 $8 2\u $z Online version $u http://www.example.com ',
        '533    $8 2\u $a Microfilm $n test note ',
        '533    $a Microfilm $n another copy ',
        '130 0  $8 1\u $a test $l test '
        ])
    end
  end
  
  describe "#remove_old_injected_fields" do
    let(:manifest) { FactoryGirl.create(:iiifmanifest, source_record: "millennium:12345", digitisation_note: 'test note') }

    let(:fields) {
      # if something gets changed in the model then this test should fail
      generated_fields = manifest.to_millennium.values.flatten
      expect(generated_fields).not_to be_empty
      generated_fields + [
        MARC::DataField.new('856', '4', '1',['8', '2\c'], ['z', 'Test version'], ['u', 'https://example.com'], ['x', 'Injected by Trifle']),
        MARC::DataField.new('856', '4', '1',['z', 'Online version'], ['u', 'http://www.example.com']),
        MARC::DataField.new('533', nil, nil,['8', '2\c'], ['a', 'Digital image'], ['n', 'test note']),
        MARC::DataField.new('533', nil, nil,['a', 'Microfilm'], ['n', 'another copy']),
        MARC::DataField.new('130', '0', nil,['8', '1\u'], ['a', 'test'], ['l', 'test']),
        MARC::DataField.new('132', '0', nil,['8', '1\u'], ['a', 'test'], ['l', 'test'])
      ]}
    it "removes injected fields" do
      kept = actor.remove_old_injected_fields(fields)
      expect(kept.map(&:to_s)).to eql([
          '856 41 $z Online version $u http://www.example.com ',
          '533    $a Microfilm $n another copy ',
          '130 0  $8 1\u $a test $l test ',
          '132 0  $8 1\u $a test $l test '
        ])
    end
  end
  
  describe "#pick_relevant_fields" do
    let(:fields) {[
        MARC::DataField.new('856', '4', '1',['8', '2\u'], ['z', 'Test version'], ['u', 'http://www.example.com']),
        MARC::DataField.new('533', nil, nil,['8', '2\u'], ['a', 'Digital image'], ['n', 'test note']),
        MARC::DataField.new('533', nil, nil,['a', 'Microfilm'], ['n', 'another copy']),
        MARC::DataField.new('130', '0', nil,['8', '1\u'], ['a', 'test'], ['l', 'test']),
        MARC::DataField.new('132', '0', nil,['8', '1\u'], ['a', 'test'], ['l', 'test'])
      ]}
    it "keeps all 856 and 533 fields" do
      relevant = actor.pick_relevant_fields(fields)
      expect(relevant.map(&:to_s)).to eql([
        '856 41 $8 2\u $z Test version $u http://www.example.com ',
        '533    $8 2\u $a Digital image $n test note ',
        '533    $a Microfilm $n another copy '
        ])
    end
  end

end