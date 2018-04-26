require 'rails_helper'

RSpec.describe Trifle::HOCRActor do
  let(:manifest) { FactoryGirl.build(:iiifmanifest) }
  let(:user) {nil}
  let(:options) { { hocr_files: [File.join(fixture_path, 'testocr-001.hocr')], language: 'Latin', canvas_offset: -1 } }
  let(:actor) { Trifle::HOCRActor.new(manifest,user,options) }

  describe "#initialize" do
  end

  describe "#process_files" do
    let(:file1) { double('file1') }
    let(:file2) { double('file2') }
    let(:options) { { hocr_files: [file1, file2]} }
    it "processes each file" do
      expect(actor).to receive(:process_file).with(file1).ordered
      expect(actor).to receive(:process_file).with(file2).ordered
      actor.process_files
    end
  end

  describe "#transform_matrix_for" do
    let(:canvas) { double('canvas', width: '1000', height: '2000') }
    let(:title) { {'bbox' => '0 0 1500 3000'} }
    let(:matrix) { actor.transform_matrix_for(canvas, title) }
    it "gives identitiy matrix as default" do
      actor.instance_variable_set(:@canvas_scale, nil)
      expect(matrix).to eql([1.0,0.0,0.0,0.0,1.0,0.0])
    end
    it "can use a set scale" do
      actor.instance_variable_set(:@canvas_scale, 2.0)
      expect(matrix).to eql([2.0,0.0,0.0,0.0,2.0,0.0])
    end
    it "can use a set matrix" do
      actor.instance_variable_set(:@transform_matrix, [1.0,2.0,3.0,4.0,5.0,6.0])
      expect(matrix).to eql([1.0,2.0,3.0,4.0,5.0,6.0])
    end
    it "can call a proc to get the matrix" do
      actor.instance_variable_set(:@transform_matrix, Proc.new do |a,b| [1.0,2.0,3.0,4.0,5.0,6.0] end)
      expect(matrix).to eql([1.0,2.0,3.0,4.0,5.0,6.0])
    end
    it "can work out scale automatically" do
      actor.instance_variable_set(:@canvas_scale, :auto)
      expect(matrix).to eql([2.0/3.0,0.0,0.0,0.0,2.0/3.0,0.0])
    end
  end

  describe "#transform_bbox" do
    it "applies matrix transform" do
      expect(actor.transform_bbox([1,2,4,3],[1.5,0,2.0,0,1.5,1.0])).to eql([3.5,4.0,8.0,5.5])
    end
  end

  describe "#process_file" do
    let(:manifest) { FactoryGirl.create(:iiifmanifest, :with_images) }
    let(:annotation_lists){ actor.instance_variable_get(:@annotation_lists) }
    let(:annotation_list) { annotation_lists[manifest.images.first.id]}
    let(:annotations) { annotation_list.annotations }
    it "parses annotations" do
      actor.process_file(options[:hocr_files].first)
      expect(annotation_lists.length).to eql(1)
      expect(annotation_list).to be_present
      expect(annotations.count).to eql(6)
      expect(annotations[0].content).to eql('Test line 1')
      expect(annotations[2].content).to eql('Test line 3')
      expect(annotations[0].language).to eql('Latin')
      expect(annotations[0].selector).to include('xywh=116,243,298,14')
      expect(annotations[5].content).to include('Test line 1')
      expect(annotations[5].content).to include('Test line 5')
    end
  end

  describe "#save_annotations" do
    let(:manifest) { FactoryGirl.create(:iiifmanifest, :with_images) }
    it "saves the manifest" do
      actor.process_file(options[:hocr_files].first)
      actor.save_annotations
      manifest.reload
      expect(manifest.images.first.annotation_lists.first.annotations.first.content).to eql('Test line 1')
    end    
  end


end