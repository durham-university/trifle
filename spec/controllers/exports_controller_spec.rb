require 'rails_helper'

RSpec.describe Trifle::ExportsController, type: :controller do

  routes { Trifle::Engine.routes }

  let(:canvas1) { FactoryGirl.create(:iiifimage, image_source: 'oubliette:oubid1')}
  let(:canvas2) { FactoryGirl.create(:iiifimage, image_source: 'oubliette:oubid2')}

  context "with admin user" do
    let(:user) { FactoryGirl.create(:user,:admin) }
    before { sign_in user }
    it "sends export job to oubliette" do
      expect(controller).to receive(:authorize_export_images).and_return(true)
      expect(controller).to receive(:get_export_images).and_call_original
      expect(controller).to receive(:get_oubliette_export_ids).and_call_original
      expect(controller).to receive(:oubliette_job_link).and_return('http://example.com/oubliette/background_jobs/1234')
      expect(Oubliette::API::PreservedFile).to receive(:export) do |params|
        expect(params[:export_ids]).to eql(['oubid1','oubid2'])
        expect(params[:export_note]).to eql('test note')
      end
      post :export_images, export_ids: ["http://example.com/manifest/2/canvas/#{canvas1.id}", canvas2.id], export_note: 'test note'
    end
  end

  context "with anonymous user" do
    describe "POST export_images" do
      it "denies access" do
        expect(controller).not_to receive(:export_params)
        expect(Oubliette::API::PreservedFile).not_to receive(:export)
        post :export_images, export_ids: [canvas1.id, canvas2.id]
      end
    end
  end
  
  context "with registered user" do
    let(:user) { FactoryGirl.create(:user) }
    before { sign_in user }
    describe "POST export_images" do
      it "denies access" do
        expect(controller).not_to receive(:export_params)
        expect(Oubliette::API::PreservedFile).not_to receive(:export)
        post :export_images, export_ids: [canvas1.id, canvas2.id]
      end
    end
  end
  
  describe "#authorize_export_images" do
    let(:image1) { double('image1') }
    let(:image2) { double('image2') }
    it "authorizes each image" do
      authorized = [false, false]
      expect(controller).to receive(:authorize!).at_least(:once) do |action, item|
        expect(action).to eql(:export)
        authorized[0] = true if(item == image1)
        authorized[1] = true if(item == image2)
      end
      controller.send(:authorize_export_images,[image1,image2])
      expect(authorized).to all( eql(true) )
    end
  end
  
  describe "#parse_export_id" do
    it "parses all types of ids" do
      expect([
          "t123abcdef",
          "https://example.com/test/manifest/t234abc/canvas/t987efg",
          "https://example.com/viewer.html?manifest=t234abc&canvas=t678bbccdd",
          "http://example.com/viewer.html?manifest=t234abc&canvas=t567ijkl&test=test",
          "ark:/12345/t789xyz"
        ].map do |id| controller.send(:parse_export_id,id) end).to eql([
          "t123abcdef",
          "t987efg",
          "t678bbccdd",
          "t567ijkl",
          "t789xyz"
        ])
    end
  end
  
  describe "#export_params" do
    it "sets export_ids" do
      allow(controller).to receive(:params).and_return({export_ids: ['test1', 'test2', 'test4', '-', 'test10', 'test13']})
      export_params = controller.send(:export_params)
      expect(export_params[:export_ids]).to eql(['test1','test2', ['test4','test10'],'test13'])
    end
    it "sets export_note" do
      allow(controller).to receive(:params).and_return({export_ids: ['test1'], export_note: 'test note'})
      export_params = controller.send(:export_params)
      expect(export_params[:export_note]).to eql('test note')
    end
  end
  
  describe "#get_export_images" do
    let(:canvas1) { FactoryGirl.build(:iiifimage, image_source: 'oubliette:oubid1')}
    let(:canvas2) { FactoryGirl.build(:iiifimage, image_source: 'oubliette:oubid2')}
    let(:canvas3) { FactoryGirl.build(:iiifimage, image_source: 'oubliette:oubid3')}
    let(:canvas4) { FactoryGirl.build(:iiifimage, image_source: 'oubliette:oubid4')}
    let(:canvas5) { FactoryGirl.build(:iiifimage, image_source: 'oubliette:oubid5')}
    let(:canvas6) { FactoryGirl.build(:iiifimage, image_source: 'oubliette:oubid6')}
    let!(:manifest1) { FactoryGirl.create(:iiifmanifest, ordered_members: [canvas1, canvas2, canvas3, canvas4] )}
    let!(:manifest2) { FactoryGirl.create(:iiifmanifest, ordered_members: [canvas5, canvas6] )}
    
    it "handles a simple list" do
      imgs = controller.send(:get_export_images,[canvas1.id, canvas2.id, canvas5.id])
      expect(imgs).to all( be_a(Trifle::IIIFImage) )
      expect(imgs.map(&:id)).to eql([canvas1.id, canvas2.id, canvas5.id])
    end
    
    it "handles ranges" do
      imgs = controller.send(:get_export_images,[[canvas1.id, canvas3.id], canvas5.id])
      expect(imgs).to all( be_a(Trifle::IIIFImage) )
      expect(imgs.map(&:id)).to eql([canvas1.id, canvas2.id, canvas3.id, canvas5.id])
    end
  end
  
  describe "#oubliette_job_link" do
    it "links to oubliette background job" do
      expect(Oubliette::API).to receive(:config).and_return({'base_url' => 'http://example.com/oubliette'})
      expect(controller.send(:oubliette_job_link,'1234-abcd-5678-efgh')).to eql('http://example.com/oubliette/background_jobs/1234-abcd-5678-efgh')
    end
  end
end