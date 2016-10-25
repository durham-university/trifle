require 'rails_helper'

RSpec.describe Trifle::ImageDepositActor do
  let(:manifest) { FactoryGirl.build(:iiifmanifest, image_container_location: 'folder') }
  let(:user) {nil}
  let(:overwrite) { false }
  let(:options) { { overwrite: overwrite } }
  let(:actor) { Trifle::ImageDepositActor.new(manifest,user,options) }

  describe "#convert_image" do
    let(:source_path) { '/tmp/dummy_source' }
    let(:dest_path) { '/tmp/dummy_dest.ptif' }
    let(:stdout) { '' }
    let(:stderr) { '' }
    let(:status) { 0 }
    before {
      expect(actor).to receive(:convert_command).and_return(['dummy'])
      expect(actor).to receive(:shell_exec).with('','dummy',source_path,dest_path,'RGB').and_return([stdout,stderr,status])
    }
    context "when things work" do
      it "returns true" do
        expect(actor.convert_image(source_path, dest_path)).to eql(true)
      end
    end
    context "when script fails" do
      let(:status) { 1 }
      let(:stderr) { "Dummy error message" }
      it "returns false and logs the error" do
        expect(actor.convert_image(source_path,dest_path)).to eql(false)
        expect(actor.log.errors?).to eql(true)
        expect(actor.log.map(&:message).join(' ')).to include('Dummy error message')
      end
    end
  end

  describe "#create_image_object" do
    before {
      actor.instance_variable_set(:@logical_path,'folder/foo.ptif')
      actor.instance_variable_set(:@image_analysis, { width: 1234, height: 4567, colour_space: 'RGB'})
      allow(Trifle).to receive(:config).and_return({'ark_naan' => '11111', 'allowed_ark_naan' => ['11111','22222']})      
    }
    let(:metadata) { { 'title' => 'Foo title', 'source_path' => 'oubliette:b0ab12cd34x', 'ark_naan' => '22222' } }
    let(:image) { actor.create_image_object(metadata) }
    it "creates an IIIFImage and sets metadata" do
      expect(image).to be_a Trifle::IIIFImage
      expect(image.title).to eql('Foo title')
      expect(image.width).to eql('1234')
      expect(image.height).to eql('4567')
      expect(image.image_location).to eql('folder/foo.ptif')
      expect(image.image_source).to eql('oubliette:b0ab12cd34x')
      expect(image.instance_variable_get(:@ark_naan)).to eql('22222')
    end
  end

  describe "#analyse_image" do
    let(:source_path) { '/tmp/dummy_dest.ptif' }
    let(:fits_out) { Nokogiri::XML(fixture('fits_out.xml').read) }
    let(:stderr) { '' }
    let(:status) { 0 }
    before {
      expect(actor).to receive(:run_fits).with(source_path).and_return([fits_out,stderr,status])
    }
    context "when things work" do
      it "returns true and sets width and height" do
        expect(actor.analyse_image(source_path)).to eql(true)
        expect(actor.instance_variable_get(:@image_analysis)[:width]).to eql(6600)
        expect(actor.instance_variable_get(:@image_analysis)[:height]).to eql(8400)
        expect(actor.instance_variable_get(:@image_analysis)[:colour_space]).to eql('RGB')
      end
    end
    context "when script fails" do
      let(:status) { 1 }
      let(:fits_out) { '' }
      let(:stderr) { "Dummy error message" }
      it "returns false and logs the error" do
        expect(actor.analyse_image(source_path)).to eql(false)
        expect(actor.log.errors?).to eql(true)
        expect(actor.log.map(&:message).join(' ')).to include('Dummy error message')
      end
    end
  end

  describe "#add_to_image_container" do
    let(:image) { FactoryGirl.build(:iiifimage) }
    let(:metadata) { { 'dummy': 'foo' } }
    before {
      expect(actor).to receive(:create_image_object).with(metadata).and_return(image)
    }
    it "adds the image using add_deposited_image" do
      expect(manifest).to receive(:add_deposited_image).with(image).and_return(true)
      expect(actor.add_to_image_container(metadata)).to eql(true)
      expect(actor.log.errors?).to eql(false)
    end
    context "when creating image fails" do
      let(:image) { nil }
      it "fails" do
        expect(manifest).not_to receive(:add_deposited_image)
        expect(actor.add_to_image_container(metadata)).to eql(false)
      end
    end
  end
  
  describe "#deposit_from_url" do
    let(:source_url) { 'http://www.example.com/dummy' }
    let(:image) { fixture('test1.jpg').read } 
    let(:metadata) { { 'basename' => 'foo' } }
    let(:response) {
      double('response').tap do |response|
        allow(response).to receive(:content_type).and_return('image/tiff')
        allow(response).to receive(:read_body) { |&block|
          image.chars.each_slice(1024).map(&:join).each(&block)
        }
      end
    }
    before {
      expect(Net::HTTP).to receive(:get_response).with(URI(source_url)).and_yield(response)
    }
    it "downloads the file, uses file extension and calls #deposit_image" do
      expect(actor).to receive(:deposit_image) { |_source_path,_metadata|
        # it needs to add source_path in metadata
        expect(_metadata).to eql(metadata.merge({'source_path' => source_url}))
        expect(File.exists?(_source_path)).to eql(true)
        expect(_source_path).to end_with('.tiff')
        expect(File.read(_source_path, binmode: true) == image).to eql(true)
      } .and_return('test value')
      expect(actor.deposit_from_url(source_url,metadata)).to eql('test value')
    end
  end
  
  describe "#deposit_from_oubliette" do
    let(:source_url) { 'oubliette:12345' }
    let(:image) { fixture('test1.jpg').read } 
    let(:metadata) { { 'basename' => 'foo' } }
    let(:response) {
      double('response').tap do |response|
        allow(response).to receive(:content_type).and_return('image/tiff')
        allow(response).to receive(:read_body) { |&block|
          image.chars.each_slice(1024).map(&:join).each(&block)
        }
      end
    }
    let(:mock_preserved_file) { double('mock_preserved_file') }
    before {
      expect(Oubliette::API::PreservedFile).to receive(:try_find).with('12345').and_return(mock_preserved_file)
      expect(mock_preserved_file).to receive(:download).and_yield(response)
    }    
    it "downloads file from oubliette" do
      expect(actor).to receive(:deposit_image) { |_source_path,_metadata|
        # it needs to add source_path in metadata
        expect(_metadata).to eql(metadata.merge({'source_path' => source_url}))
        expect(File.exists?(_source_path)).to eql(true)
        expect(_source_path).to end_with('.tiff')
        expect(File.read(_source_path, binmode: true) == image).to eql(true)
      } .and_return('test value')
      expect(actor.deposit_from_oubliette(source_url,metadata)).to eql('test value')
    end
  end

  describe "#deposit_image" do
    before {
      allow(Trifle).to receive(:config).and_return({
          'image_server_config' => {
            'images_root' => 'dummy_iipi_dir',
            'local_copy' => true
          }
        })
    }
    
    let(:container_dir){'folder'}
    before {
      allow(actor).to receive(:file_path).and_return('foo')
      allow(actor).to receive(:container_dir).and_return(container_dir)
      allow(actor).to receive(:image_format).and_return('ptif')
      allow(actor).to receive(:image_base_path).and_return('/tmp/base')

      allow(actor).to receive(:analyse_image).with(source_path).and_return(true)
      allow(actor).to receive(:convert_image).and_return(true)
      allow(actor).to receive(:send_or_copy_file).and_return(true)
      allow(actor).to receive(:add_to_image_container).and_return(true)
    }
    let(:source_path) { '/tmp/source' }
    let(:metadata) { { 'basename' => 'foo', dummy: 'dummy' } }
    let(:metadata_with_source) { metadata.merge('source_path' => source_path)}
    
    context "with http:// path" do
      let(:source_path) { 'http://www.example.com/dummy' }
      it "delegates to deposit_url if path starts with http://" do
        expect(actor).to receive(:deposit_from_url).with(source_path, metadata).and_return('test value')
        expect(actor.deposit_image(source_path, metadata)).to eql('test value')
      end
    end
    context "with https:// path" do
      let(:source_path) { 'https://www.example.com/dummy' }
      it "delegates to deposit_url if path starts with https://" do
        expect(actor).to receive(:deposit_from_url).with(source_path, metadata).and_return('test value')
        expect(actor.deposit_image(source_path, metadata)).to eql('test value')
      end
    end

    it "fails if no container_dir" do
      expect(actor).to receive(:container_dir).and_return(nil)
      expect(actor.deposit_image(source_path,metadata)).to eql(false)
      expect(actor.log.errors?).to eql(true)
    end

    it "sets @logical_path" do
      actor.deposit_image(source_path,metadata)
      expect(actor.instance_variable_get(:@logical_path)).to eql("folder/foo.ptif")
    end

    it "calls other actions" do
      convert_temp=''
      expect(actor).to receive(:convert_image) do |src, convert_path|
        expect(src).to eql(source_path)
        expect(convert_path).to start_with(Dir.tmpdir)
        expect(convert_path).to end_with('.ptif')
        convert_temp = convert_path
        true
      end
      expect(actor).to receive(:analyse_image).and_return(true)
      expect(actor).to receive(:send_or_copy_file) do |convert_path,dest_path, params|
        expect(convert_path).to eql(convert_temp)
        expect(dest_path).to eql('/tmp/base/folder/foo.ptif')
        expect(params[:local_copy]).to eql(true)
        true
      end
      expect(actor).to receive(:add_to_image_container).with(metadata_with_source.stringify_keys).and_return(true)
      expect(actor.deposit_image(source_path,metadata)).to eql(true)
    end
        
    it "doesn't overwrite source_path" do
      expect(actor).to receive(:add_to_image_container).with({'source_path' => 'moo'})
      actor.deposit_image(source_path, {'source_path' => 'moo'})
    end

    context "with malicious data" do
      let(:container_dir){'../folder'}
      it "sanitises destination path" do
        expect(actor.deposit_image(source_path,metadata)).to eql(false)
        expect(actor.log.last.level).to eql(:error)
        expect(actor.log.last.message).to start_with("Suspicious container_dir")
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

  describe "#deposit_image_batch" do
    it "calls deposit_image with matadata" do
      expect(actor).to receive(:deposit_image).with('/tmp/source',{'dummy' => 'dummy', 'title' => '1'}).and_return true
      # note mixed use of string and symbol keys to test that both work
      ret_val = actor.deposit_image_batch([{'source_path' => '/tmp/source', dummy: 'dummy'}])
      expect(ret_val).to eql(true)
    end

    it "calls deposit_image once for each image" do
      expect(actor).to receive(:deposit_image).exactly(3).times.and_return(false)
      ret_val = actor.deposit_image_batch([{'source_path' => '1'},{'source_path' => '2'},{'source_path' => '3'}])
      expect(ret_val).to eql(false)
    end
  end

  describe "#file_path" do
    it "returns from metadata if set" do
      expect(actor.send(:file_path,{'basename' => 'moo'})).to eql('moo')
    end
    it "returns a random path if not set" do
      expect(actor.send(:file_path,{})).to be_present
    end
  end

  describe "#container_dir" do
    it "returns container from model_object" do
      expect(actor.send(:container_dir)).to eql(manifest.image_container_location)
    end
  end

  describe "configuration methods" do
    before {
      allow(Trifle).to receive(:config).and_return({
          'image_convert_format' => 'dummy_format',
          'image_convert_command' => ['dummy_convert_command'],
          'image_convert_temp_dir' => '/tmp/dummy',
          'image_server_config' => {
            'images_root' => 'dummy_iipi_dir'
          }
        })
    }

    describe "#image_base_path" do
      it "returns set dir" do
        expect(actor.send(:image_base_path)).to eql('dummy_iipi_dir')
      end
    end

    describe "#image_format" do
      it "returns set format" do
        expect(actor.send(:image_format)).to eql('dummy_format')
      end
    end

    describe "#convert_command" do
      it "returns set command" do
        expect(actor.send(:convert_command)).to eql(['dummy_convert_command'])
      end
    end

    describe "#temp_dir" do
      context "with temp_dir set" do
        it "returns set dir" do
          expect(actor.send(:temp_dir)).to eql('/tmp/dummy')
        end
      end
      context "with no temp_dir set" do
        let(:temp_dir) { nil }
        it "returns system dir" do
          Trifle.config.delete('image_convert_temp_dir')
          expect(actor.send(:temp_dir)).to eql(Dir.tmpdir)
        end
      end
    end
  end

end
