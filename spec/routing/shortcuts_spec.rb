require "rails_helper"

RSpec.describe Trifle::ApplicationController, type: :routing do
  routes { Trifle::Engine.routes }
  let(:annotation) { FactoryGirl.create(:iiifannotation, :with_manifest) }
  let(:annotation_list) { annotation.parent }
  let(:image) { annotation_list.parent }
  let(:range) { FactoryGirl.create(:iiifrange, :with_manifest) }
  
  it "implements shortcut routes" do
    expect(iiif_image_path(image)).to be_present
    expect(edit_iiif_image_path(image)).to be_present
    expect(new_iiif_image_path(image)).to be_present
    expect(iiif_image_iiif_path(image)).to be_present
    expect(iiif_image_annotation_iiif_path(image)).to be_present
    expect(iiif_annotation_list_path(annotation_list)).to be_present
    expect(edit_iiif_annotation_list_path(annotation_list)).to be_present
    expect(iiif_annotation_list_iiif_path(annotation_list)).to be_present
    expect(iiif_annotation_path(annotation)).to be_present
    expect(edit_iiif_annotation_path(annotation)).to be_present
    expect(iiif_annotation_iiif_path(annotation)).to be_present
    expect(new_iiif_annotation_list_iiif_annotation_path(annotation_list)).to be_present
    expect(iiif_annotation_list_iiif_annotations_path(annotation_list)).to be_present
    expect(iiif_range_path(range)).to be_present
    expect(edit_iiif_range_path(range)).to be_present
    expect(new_iiif_range_path(range)).to be_present
    expect(new_iiif_range_iiif_range_path(range)).to be_present
    expect(iiif_range_iiif_ranges_path(range)).to be_present
    expect(iiif_image_iiif_annotation_lists_path(image)).to be_present
    expect(new_iiif_image_iiif_annotation_list_path(image)).to be_present
    expect(iiif_image_all_annotations_path(image)).to be_present
  end
end