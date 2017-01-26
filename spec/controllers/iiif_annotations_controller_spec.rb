require 'rails_helper'

RSpec.describe Trifle::IIIFAnnotationsController, type: :controller do

  let(:annotation_list) { FactoryGirl.create(:iiifannotationlist, :with_manifest) }
  let(:image) { FactoryGirl.create(:iiifimage, :with_manifest) }
  
  let(:annotation_params) { { title: 'new annotation', format: 'text/html', language: 'en', content: 'test content', selector: '{"@type" : "oa:FragmentSelector", "value" : "xywh=1,2,3,4" }' } }

  routes { Trifle::Engine.routes }
  
  context "with admin user" do
    let(:user) { FactoryGirl.create(:user,:admin) }
    before { sign_in user }
    
    describe "PUT #update" do
      let(:annotation) { FactoryGirl.create(:iiifannotation,:with_manifest)}
      it "returns iiif when requested" do
        put :update, reply_iiif: 'true', id: annotation.id, iiif_annotation: annotation_params, iiif_manifest_id: 'dummy'
        json = JSON.parse(response.body)
        expect(json['@type']).to eql('oa:Annotation')
        expect(json['on']).to be_present
        expect(json['resource']).to be_present
        expect(json['resource']['chars']).to eql('test content')
      end      
      
      it "marks containing manifest dirty" do
        manifest = annotation.manifest
        manifest.set_clean
        manifest.save
        put :update, reply_iiif: 'true', id: annotation.id, iiif_annotation: annotation_params, iiif_manifest_id: 'dummy'
        expect(manifest.reload).to be_dirty
      end
    end
    
    describe "POST #create" do
      it "returns iiif when requested" do
        post :create, reply_iiif: 'true', iiif_annotation: annotation_params, iiif_annotation_list_id: annotation_list.id, iiif_manifest_id: 'dummy'
        json = JSON.parse(response.body)
        expect(json['@type']).to eql('oa:Annotation')
        expect(json['on']).to be_present
        expect(json['resource']).to be_present
      end
      
      it "marks containing manifest dirty" do
        manifest = annotation_list.manifest
        manifest.set_clean
        manifest.save
        post :create, reply_iiif: 'true', iiif_annotation: annotation_params, iiif_annotation_list_id: annotation_list.id, iiif_manifest_id: 'dummy'
        expect(manifest.reload).to be_dirty
      end
      
      context "with annotation_list" do
        it "adds to the annotation list" do
          expect(annotation_list.annotations.count).to eql(0)
          post :create, iiif_annotation: annotation_params, iiif_annotation_list_id: annotation_list.id, iiif_manifest_id: 'dummy'
          reloaded_list = Trifle::IIIFAnnotationList.find(annotation_list.id)
          expect(reloaded_list.annotations.count).to eql(1)
          annotation = reloaded_list.annotations.first
          expect(annotation.title).to eql('new annotation')
          expect(annotation.content).to eql('test content')
          expect(annotation.format).to eql('text/html')
          expect(annotation.language).to eql('en')
          expect(annotation.selector).to include('xywh=1,2,3,4')
          
          post :create, iiif_annotation: annotation_params, iiif_annotation_list_id: annotation_list.id, iiif_manifest_id: 'dummy'
          reloaded_list = Trifle::IIIFAnnotationList.find(annotation_list.id)
          expect(reloaded_list.annotations.count).to eql(2)     
        end
      end
      
      context "with image" do
        it "creates a new annotation list if needed and adds to it" do
          expect(image.annotation_lists.count).to eql(0)
          post :create, iiif_annotation: annotation_params, iiif_image_id: image.id, iiif_manifest_id: 'dummy'
          image.reload
          expect(image.annotation_lists.count).to eql(1)
          annotation_list = image.annotation_lists.first
          expect(annotation_list.title).to be_present
          expect(annotation_list.annotations.count).to eql(1)
          annotation = annotation_list.annotations.first
          expect(annotation.title).to eql('new annotation')
          expect(annotation.content).to eql('test content')
          expect(annotation.format).to eql('text/html')
          expect(annotation.language).to eql('en')
          expect(annotation.selector).to include('xywh=1,2,3,4')
          
          post :create, iiif_annotation: annotation_params, iiif_image_id: image.id, iiif_manifest_id: 'dummy'
          image.reload
          expect(image.annotation_lists.count).to eql(1)
          expect(image.annotation_lists.first.annotations.count).to eql(2)
        end
      end
    end
  end
  

end