require 'rails_helper'

RSpec.describe Trifle::PublishIIIFActor do
  let(:trifle_config) { { 'ark_naan' => '12345', 'published_iiif_url' => 'http://www.example.com/iiif/'} }
  before {
    config = Trifle.config.merge(trifle_config)
    allow(Trifle).to receive(:config).and_return(config)
  }
  let(:full_manifest) { 
    FactoryGirl.create(:iiifmanifest, :with_images, :with_parent, identifier: ['ark:/12345/t0bc12df34x']).tap do |man| 
      range = FactoryGirl.create(:iiifrange, manifest: man)
      range.assign_id!
      man.ranges << range
      sub_range = FactoryGirl.create(:iiifrange, manifest: man)
      sub_range.canvases = [man.images[0]]
      sub_range.assign_id!
      range.canvases = man.images
      range.sub_ranges << sub_range
      man.serialise_ranges
      man.save
      image = man.images.first
      image.annotation_lists.push(FactoryGirl.create(:iiifannotationlist, :with_annotations, parent: image))
      image.serialise_annotations
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
  let(:actor) { Trifle::PublishIIIFActor.new(manifest,user,options) }

  describe "#upload_package" do
    let(:package) { [double('entry1', path: '123/manifest', content: 'manifest content'), 
                     double('entry2', path: '123/sequence/default', content: 'default content')
                    ].to_enum }
    let(:trifle_config) { { 
      'ark_naan' => '12345',
      'published_iiif_url' => 'http://www.example.com/iiif/',
      'image_server_config' => {
        'host' => 'example.com',
        'user' => 'testuser',
        'iiif_root' => '/iiif'
      }
    } }
    
    before {
      expect(actor).to receive(:iiif_package).and_return(package)
      allow(actor).to receive(:send_or_copy_file).and_return(true)
    }
    
    it "uploads all files" do
      sent_files = []
      expect(actor).to receive(:send_or_copy_file).at_least(:once) do |file,path,params|
        sent_files << path
        expect(file.read).to eql("#{path.split('/').last} content")
        expect(params[:host]).to eql('example.com')
        expect(params[:user]).to eql('testuser')
        true
      end
      actor.upload_package
      expect(sent_files).to match_array(['/iiif/123/manifest','/iiif/123/sequence/default'])
    end
    
    context "dirty_state" do
      let(:manifest) {full_manifest}
      it "marks object clean" do
        expect(manifest).to be_dirty
        actor.upload_package
        expect(manifest.reload).to be_clean
      end
    end
  end
  
  describe "#send_or_copy_file" do
    let(:connection_params) { { 'test' => 'dummy' } }
    let(:source) { double('source') }
    let(:dest) { double('dest') }
    it "sends over ssh" do
      expect(actor).to receive(:send_file).with(source, dest, hash_including('test'=>'dummy'))
      expect(actor).not_to receive(:copy_file_local)
      actor.send_or_copy_file(source, dest, connection_params)
    end
    it "copies locally" do
      connection_params[:local_copy] = true
      expect(actor).to receive(:copy_file_local).with(source, dest, hash_including('test'=>'dummy'))
      expect(actor).not_to receive(:send_file)
      actor.send_or_copy_file(source, dest, connection_params)
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
  
  describe "#remove_remote_package" do
    let(:trifle_config) { { 
      'ark_naan' => '12345',
      'published_iiif_url' => 'http://www.example.com/iiif/',
      'image_server_config' => {
        'host' => 'example.com',
        'user' => 'testuser',
        'iiif_root' => '/iiif'
      }
    } }
    context "with a manifest" do
      it "removes the directory" do
        expect(actor).to receive(:sftp_rm_rf).with('/iiif/12345/t0/bc/12/t0bc12df34x',hash_including(:host, :user)).and_return(true)
        actor.remove_remote_package('ark:/12345/t0bc12df34x','manifest')
      end
    end
    context "with a collection" do
      it "removes the file" do
        expect(actor).to receive(:sftp_rm_rf).with('/iiif/collection/t0bc12df34x',hash_including(:host, :user)).and_return(true)
        actor.remove_remote_package('t0bc12df34x','collection')
      end
    end
  end

  describe "#iiif_package_unstatified" do
    let(:enum) { actor.iiif_package_unstatified }
    let(:entries) { enum.to_a }
    context "with a manifest" do
      let(:manifest) { full_manifest }
      let(:iiif) { entries.find do |e| e.path.ends_with?('/manifest') end .content }
      let(:prefix) { actor.send(:treeify_id) }
      it "adds all the entries" do
        expect(enum).to be_a(Enumerator)
        expect(entries.map(&:path)).to match_array([
            "#{prefix}/manifest", "#{prefix}/sequence/default",
            "#{prefix}/range/#{manifest.ranges.first.id}",
            "#{prefix}/range/#{manifest.ranges.first.sub_ranges.first.id}",
            *(manifest.images.map do |img| "#{prefix}/canvas/#{img.id}" end),
            *(manifest.images.map do |img| "#{prefix}/annotation/canvas_#{img.id}" end),
            "#{prefix}/list/#{manifest.images.first.annotation_lists.first.id}",
            *(manifest.images.first.annotation_lists.first.annotations.map do |ann| "#{prefix}/annotation/#{ann.id}" end),
            "collection/12345/#{manifest.parent.id}"
          ])
        expect(iiif).to be_a(IIIF::Presentation::Manifest)
      end
    end
    
    context "with a collection" do
      # variable manifest is really a collection!
      let(:manifest) { FactoryGirl.create(:iiifcollection, :with_manifests, :with_parent)}
      let(:iiif) { entries.find do |e| e.path.ends_with?("collection/12345/#{manifest.id}") end .content }
      it "works with a collection object" do
        expect(enum).to be_a(Enumerator)
        expect(entries.map(&:path)).to match_array([
            "collection/12345/#{manifest.id}",
            "collection/12345/#{manifest.parent.id}"
          ])
        expect(iiif).to be_a(IIIF::Presentation::Collection)
      end
    end
    
    context "with a top-level collection" do
      # variable manifest is really a collection!
      let(:manifest) { FactoryGirl.create(:iiifcollection, :with_manifests)}
      let(:iiif) { entries.find do |e| e.path.ends_with?("collection/12345/#{manifest.id}") end .content }
      it "works with a collection object" do
        expect(enum).to be_a(Enumerator)
        expect(entries.map(&:path)).to match_array([
            "collection/12345/#{manifest.id}",
            "collection/index"
          ])
        expect(iiif).to be_a(IIIF::Presentation::Collection)
      end
    end
    
    context "with a parameter object" do
      let(:enum) { actor.iiif_package_unstatified(other_object) }
      let(:manifest) { FactoryGirl.create(:iiifcollection, :with_manifests) }
      let(:other_object) { FactoryGirl.create(:iiifcollection,:with_manifests) }
      it "can take an object as a parameter" do
        expect(entries.map(&:path)).to include("collection/12345/#{other_object.id}")
        expect(entries.map(&:path)).not_to include("collection/12345/#{manifest.id}")
      end
    end
  end
  
  describe "#iiif_package" do
    let(:file_entry1) { double('file_entry_1') }
    let(:file_entry2) { double('file_entry_2') }
    let(:unstatified) { Enumerator.new do |y| y << file_entry1 ; y << file_entry2 ; end }
    let(:statified1) { double('statified_1') }
    let(:statified2) { double('statified_2') }
    before {
      allow(actor).to receive(:statify_file).and_raise('unexpected file')
      expect(actor).to receive(:statify_file).with(file_entry1).and_return(statified1)
      expect(actor).to receive(:statify_file).with(file_entry2).and_return(statified2)      
    }
    it "statifies package and enumerates it" do
      expect(actor).to receive(:iiif_package_unstatified).and_return(unstatified)
      expect(actor.iiif_package.to_a).to eql([statified1, statified2])
    end
    let(:other_object) { double('other_object') }
    it "passes the parameter" do
      expect(actor).to receive(:iiif_package_unstatified).with(other_object).and_return(unstatified)
      expect(actor.iiif_package(other_object).to_a).to eql([statified1, statified2])
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
  
  describe "#rails_manifest_prefix" do
    it "returns route prefix to manifest" do
      expect(actor.send(:rails_manifest_prefix)).to eql("#{Trifle.iiif_host}/trifle/iiif/manifest/")
    end
  end
  
  describe "#rails_collection_prefix" do
    it "returns route prefix to collection" do
      expect(actor.send(:rails_collection_prefix)).to eql("#{Trifle.iiif_host}/trifle/iiif/collection/")
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
    before {
      allow(actor).to receive(:rails_manifest_prefix).and_return("http://www.example.com/trifle/iiif/manifest/")
      allow(actor).to receive(:rails_collection_prefix).and_return("http://www.example.com/trifle/iiif/collection/")
      allow(Trifle).to receive(:config).and_return({'published_iiif_url' => 'http://imageserver/iiif/'})
      allow(actor).to receive(:ark_naan).and_return('12345')
    }
    context "with manifest uris" do
      let(:uri) { "http://www.example.com/trifle/iiif/manifest/#{manifest.id}/annotation/ttr243b49tvy" }
      it "converts uris that start with the prefix" do
        expect(actor).to receive(:treeified_prefix).and_return('http://imageserver/iiif/12345/t0/bc/12/t0bc12df34x/')
        expect(actor.send(:convert_id, uri)).to eql('http://imageserver/iiif/12345/t0/bc/12/t0bc12df34x/annotation/ttr243b49tvy')
      end
    end
    context "with collection uris" do
      let(:uri) { "http://www.example.com/trifle/iiif/collection/ttr243b49tvy" }
      it "converts uris that start with the prefix" do
        expect(actor.send(:convert_id, uri)).to eql('http://imageserver/iiif/collection/12345/ttr243b49tvy')
      end
    end
    context "with the collection index uri" do
      let(:uri) { "http://www.example.com/trifle/iiif/collection" }
      it "converts the index uri" do
        expect(actor.send(:convert_id, uri)).to eql('http://imageserver/iiif/collection/index')
      end
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
    context "with manifest" do
      it "converts all ids in manifest iiif" do
        expect(source_s).to include(actor.send(:rails_manifest_prefix))
        expect(converted_s).not_to include(actor.send(:rails_manifest_prefix))
      end
    end
    context "with collection" do
      let(:manifest) { FactoryGirl.create(:iiifcollection, :with_manifests, :with_parent) }
      it "converts all ids in collection iiif" do
        expect(source_s).to include(actor.send(:rails_manifest_prefix))
        expect(source_s).to include(actor.send(:rails_collection_prefix))
        expect(converted_s).not_to include(actor.send(:rails_manifest_prefix))
        expect(converted_s).not_to include(actor.send(:rails_collection_prefix))
      end
    end
  end

end