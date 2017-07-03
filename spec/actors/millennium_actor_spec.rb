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

  describe "#millennium_package" do
    before {
      expect(manifest).to receive(:to_millennium_all).and_return({
        'mid1234' => [
          MARC::DataField.new('856', '4', '1',['z', 'Online version'], ['u', 'http://www.example.com/trifle_link']),
          MARC::DataField.new('533', nil, nil,['a', 'Digital image'], ['n', 'test note'])
        ],
        'mid5678' => [ MARC::DataField.new('533', nil, nil,['a', 'Digital image'], ['n', 'another test']) ]
      })
      expect(actor).to receive(:preserved_millennium_fields).twice.and_return([
          MARC::DataField.new('856', '4', '1',['z', 'Online version'], ['u', 'http://www.example.com/preserved_link'])
        ])
    }
    it "gets all millennium records" do
      package = actor.millennium_package.to_a
      expect(package.length).to eql(2)
      expect(package[0].path).to eql('mid1234')
      contents = package[0].content.to_s
      expect(contents).to start_with('<?xml version=\'1.0\'?>')
      expect(contents).to include('<collection')
      expect(contents).to include('</collection>') # make sure the xml writer is closed properly
      expect(contents).to include('Online version')
      expect(contents).to include('test note')
      expect(contents).to include('http://www.example.com/preserved_link')
      expect(contents).to include('http://www.example.com/trifle_link')
      expect(package[1].path).to eql('mid5678')
      expect(package[1].content.to_s).to include("another test")
    end
  end

  describe "#preserved_millennium_fields" do
    let(:manifest) { FactoryGirl.create(:iiifmanifest, source_record: "millennium:12345", digitisation_note: 'test note') }
    let(:mock_connection) { double('mock_connection')}
    let(:millennium_id) { 'abcdefgh' }
    let(:marc_record) {
      MARC::Record.new().tap do |r|
        manifest.to_millennium.each do |k,fs|
          fs.each do |f|
            r.append(f)
          end
        end
        expect(r.fields.select do |f| f.tag == '856' end).not_to be_empty
        expect(r.fields.select do |f| f.tag == '533' end).not_to be_empty
        r.append(MARC::DataField.new('856', '4', '1',['z', 'Online version'], ['u', 'http://www.example.com']))
        r.append(MARC::DataField.new('533', nil, nil,['a', 'Microfilm'], ['n', 'test note']))
        r.append(MARC::DataField.new('533', nil, nil,['a', 'Microfilm'], ['n', 'another copy']))
        r.append(MARC::DataField.new('130', '0', nil,['a', 'test'], ['l', 'test']))
      end
    }
    before {
      expect(DurhamRails::LibrarySystems::Millennium).to receive(:connection).and_return(mock_connection)
      expect(mock_connection).to receive(:record).with(millennium_id).and_return(double('mock_record',marc_record: marc_record))
    }
    
    it "preserves only fields not created by Trifle" do
      fs = actor.preserved_millennium_fields(millennium_id)
      expect(fs.count).to eql(3)
      expect(fs.find do |f| f.tag == '130' end).to be_nil # don't return irrelevant fields
      f856 = fs.select do |f| f.tag == '856' end
      f533 = fs.select do |f| f.tag == '533' end
        
      expect(f856.count).to eql(1)
      expect(f856[0]['u']).to eql('http://www.example.com')
      expect(f533.count).to eql(2)
      expect(f533[0]['n']).to eql('test note')
      expect(f533[1]['n']).to eql('another copy')
    end
  end

end