require 'rails_helper'

RSpec.describe Trifle::StaticIIIFActor do
  let(:trifle_config) { { 'ark_naan' => '12345', 'static_iiif_url' => 'http://www.example.com/iiif/'} }
  before {
    config = Trifle.config.merge(trifle_config)
    allow(Trifle).to receive(:config).and_return(config)
  }
  let(:full_manifest) { 
    FactoryGirl.create(:iiifmanifest, :with_images, identifier: ['ark:/12345/t0bc12df34x']).tap do |man| 
      range = FactoryGirl.create(:iiifrange)
      range.ordered_members += man.images
      range.save
      man.ordered_members << range
      man.save
      image = man.images.first
      image.ordered_members << FactoryGirl.create(:iiifannotationlist, :with_annotations)
      image.save
    end
  }
  let(:fast_manifest) {
    FactoryGirl.build(:iiifmanifest, identifier: ['ark:/12345/t0bc12df34x']).tap do |man|
      allow(man).to receive(:id).and_return('t0bc12df34x')
      allow(man).to receive(:to_param).and_return('t0bc12df34x')
    end
  }
  let(:manifest) { fast_manifest }
  let(:user) {nil}
  let(:options) { { } }
  let(:actor) { Trifle::StaticIIIFActor.new(manifest,user,options) }

  describe "#upload_package" do
    let(:package) { [double('entry1', path: '123/manifest', content: 'manifest content'), 
                     double('entry2', path: '123/sequence/default', content: 'default content')
                    ].to_enum }
    let(:trifle_config) { { 
      'ark_naan' => '12345',
      'static_iiif_url' => 'http://www.example.com/iiif/',
      'image_server_ssh' => {
        'host' => 'example.com',
        'user' => 'testuser',
        'iiif_root' => '/iiif'
      }
    } }
    
    it "uploads all files" do
      expect(actor).to receive(:iiif_package).and_return(package)
      sent_files = []
      expect(actor).to receive(:send_file).at_least(:once) do |file,path,params|
        sent_files << path
        expect(file.read).to eql("#{path.split('/').last} content")
        expect(params[:host]).to eql('example.com')
        expect(params[:user]).to eql('testuser')
      end
      actor.upload_package
      expect(sent_files).to match_array(['/iiif/123/manifest','/iiif/123/sequence/default'])
    end
  end
  
  describe "#write_package" do
    let(:package) { [double('entry1', path: '123/manifest', content: 'manifest content'), 
                     double('entry2', path: '123/sequence/default', content: 'default content')
                    ].to_enum }
    it "writes all files" do
      expect(actor).to receive(:iiif_package).and_return(package)
      expect(FileUtils).to receive(:mkdir_p).with('/tmp/iiif-test/123')
      expect(FileUtils).to receive(:mkdir_p).with('/tmp/iiif-test/123/sequence')
      expect(File).to receive(:open).with('/tmp/iiif-test/123/manifest','wb') do |&block|
        block.call(double('file').tap do |d| expect(d).to receive('write') end)
      end
      expect(File).to receive(:open).with('/tmp/iiif-test/123/sequence/default','wb') do |&block|
        block.call(double('file').tap do |d| expect(d).to receive('write') end)
      end
      actor.write_package('/tmp/iiif-test')
    end
  end

  describe "#iiif_package_unstatified" do
    let(:manifest) { full_manifest }
    let(:enum) { actor.iiif_package_unstatified }
    let(:entries) { enum.to_a }
    let(:iiif) { entries.find do |e| e.path.ends_with?('/manifest') end .content }
    let(:prefix) { actor.send(:treeify_id) }
    it "adds all the entries" do
      expect(enum).to be_a(Enumerator)
      expect(entries.map(&:path)).to match_array([
          "#{prefix}/manifest", "#{prefix}/sequence/default", "#{prefix}/range/#{manifest.ranges.first.id}",
          *(manifest.images.map do |img| "#{prefix}/canvas/#{img.id}" end),
          *(manifest.images.map do |img| "#{prefix}/annotation/canvas_#{img.id}" end),
          "#{prefix}/list/#{manifest.images.first.annotation_lists.first.id}",
          *(manifest.images.first.annotation_lists.first.annotations.map do |ann| "#{prefix}/annotation/#{ann.id}" end),
        ])
      expect(iiif).to be_a(IIIF::Presentation::Manifest)
    end
  end
  
  describe "#iiif_package" do
    let(:file_entry1) { double('file_entry_1') }
    let(:file_entry2) { double('file_entry_2') }
    let(:unstatified) { Enumerator.new do |y| y << file_entry1 ; y << file_entry2 ; end }
    let(:statified1) { double('statified_1') }
    let(:statified2) { double('statified_2') }
    it "statifies package and enumerates it" do
      allow(actor).to receive(:statify_file).and_raise('unexpected file')
      expect(actor).to receive(:statify_file).with(file_entry1).and_return(statified1)
      expect(actor).to receive(:statify_file).with(file_entry2).and_return(statified2)
      expect(actor).to receive(:iiif_package_unstatified).and_return(unstatified)
      expect(actor.iiif_package.to_a).to eql([statified1, statified2])
    end
  end
  
  describe "#statify_file" do
    let(:file_entry) { double('file_entry', path: 'mock_path', content: 'mock_content') }
    let(:converted_content) { 
      double('converted_iiif').tap do |content|
        allow(content).to receive(:to_json).and_return('converted_mock_content')
      end
    }
    let(:statified) { actor.send(:statify_file, file_entry) }
    before { expect(actor).to receive(:convert_ids).with(file_entry.content).and_return(converted_content) }
    it "statifies file" do
      expect(statified.path).to eql('mock_path')
      expect(statified.content).to be_a(String)
      expect(statified.content).to eql('converted_mock_content')
    end
  end
  
  describe "#rails_id_prefix" do
    it "returns route prefix to manifest" do
      expect(actor.send(:rails_id_prefix)).to eql("#{Trifle.iiif_host}/trifle/iiif/manifest/#{manifest.id}/")
    end
  end
  
  describe "#treeify_id" do
    it "treeifies id" do
      expect(actor.send(:treeify_id)).to eql('12345/t0/bc/12/t0bc12df34x')
    end
  end
  
  describe "#treeified_prefix" do
    before { expect(actor).to receive(:treeify_id).and_return('12345/t0/bc/12/t0bc12df34x') }
    it "adds treeified id to prefix" do
      expect(actor.send(:treeified_prefix)).to eql('http://www.example.com/iiif/12345/t0/bc/12/t0bc12df34x/')
    end
  end
  
  describe "#convert_id" do
    let(:uri) { "http://www.example.com/trifle/iiif/manifest/#{manifest.id}/annotation/ttr243b49tvy" }
    before { allow(actor).to receive(:rails_id_prefix).and_return("http://www.example.com/trifle/iiif/manifest/#{manifest.id}/") }
    it "converts uris that start with the prefix" do
      expect(actor).to receive(:treeified_prefix).and_return('http://imageserver/iiif/12345/t0/bc/12/t0bc12df34x/')
      expect(actor.send(:convert_id, uri)).to eql('http://imageserver/iiif/12345/t0/bc/12/t0bc12df34x/annotation/ttr243b49tvy')
    end
    it "returns other uris untouched" do
      expect(actor.send(:convert_id,'http://www.somethingelse.com/moo')).to eql('http://www.somethingelse.com/moo')
    end
  end
  
  describe "#convert_ids" do
    let(:manifest) { full_manifest }
    let(:source) { manifest.to_iiif }
    let(:source_s) { source.to_json(pretty: true) }
    let(:converted) { actor.send(:convert_ids,source) }
    let(:converted_s) { converted.to_json(pretty: true) }
    it "converts all ids" do
      expect(source_s).to include(actor.send(:rails_id_prefix))
      expect(converted_s).not_to include(actor.send(:rails_id_prefix))
    end
  end

end