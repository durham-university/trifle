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
      expect(actor).to receive(:shell_exec).with('','dummy',source_path,dest_path).and_return([stdout,stderr,status])
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
    before { actor.instance_variable_set(:@logical_path,'folder/foo.ptif')}
    let(:metadata) { { title: 'Foo title' } }
    let(:image) { actor.create_image_object(metadata) }
    it "creates an IIIFImage and sets metadata" do
      expect(image).to be_a Trifle::IIIFImage
      expect(image.title).to eql('Foo title')
      expect(image.image_location).to eql('folder/foo.ptif')
    end
  end

  describe "#analyse_image" do
    # TODO
  end

  describe "#add_to_image_container" do
    let(:image) { FactoryGirl.build(:iiifimage) }
    let(:metadata) { { dummy: 'foo' } }
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

  describe "#deposit_image" do
    before {
      allow(actor).to receive(:file_path).and_return('foo')
      allow(actor).to receive(:container_dir).and_return('folder')
      allow(actor).to receive(:image_format).and_return('ptif')
      allow(actor).to receive(:image_base_path).and_return('/tmp/base')

      allow(actor).to receive(:convert_image).and_return(true)
      allow(actor).to receive(:analyse_image).and_return(true)
      allow(actor).to receive(:add_to_image_container).and_return(true)
    }
    let(:source_path) { '/tmp/source' }
    let(:metadata) { { basename: 'foo' } }

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
      expect(actor).to receive(:convert_image).with(source_path,'/tmp/base/folder/foo.ptif').and_return(true)
      expect(actor).to receive(:analyse_image).and_return(true)
      expect(actor).to receive(:add_to_image_container).with(metadata).and_return(true)
      expect(actor.deposit_image(source_path,metadata)).to eql(true)
    end

    it "doesn't overwrite by default" do
      expect(File).to receive(:exists?).with('/tmp/base/folder/foo.ptif').and_return(true)
      expect(actor.deposit_image(source_path,metadata)).to eql(false)
      expect(actor.log.errors?).to eql(true)
    end

    it "overwrites if @overwrite is set" do
      actor.instance_variable_set(:@overwrite, true)
      expect(File).to receive(:exists?).with('/tmp/base/folder/foo.ptif').and_return(true)
      expect(actor.deposit_image(source_path,metadata)).to eql(true)
      expect(actor.log.errors?).to eql(false)
    end

  end

  describe "#deposit_image_batch" do
    it "calls deposit_image with matadata" do
      expect(actor).to receive(:deposit_image).with('/tmp/source',{dummy: 'dummy'}).and_return true
      ret_val = actor.deposit_image_batch([{source_path: '/tmp/source', dummy: 'dummy'}])
      expect(ret_val).to eql(true)
    end

    it "calls deposit_image once for each image" do
      expect(actor).to receive(:deposit_image).exactly(3).times.and_return(false)
      ret_val = actor.deposit_image_batch([{source_path: '1'},{source_path: '2'},{source_path: '3'}])
      expect(ret_val).to eql(false)
    end
  end

  describe "#file_path" do
    it "returns from metadata if set" do
      expect(actor.send(:file_path,{basename: 'moo'})).to eql('moo')
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
          'iipi_dir' => 'dummy_iipi_dir',
          'image_convert_format' => 'dummy_format',
          'image_convert_command' => ['dummy_convert_command'],
          'image_convert_temp_dir' => '/tmp/dummy'
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
