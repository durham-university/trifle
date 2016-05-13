require 'rails_helper'

RSpec.describe Trifle::TrackDirtyStateBehaviour do

  before {
    class Foo < ActiveFedora::Base
      include Trifle::TrackDirtyStateBehaviour      
      include Hydra::Works::WorkBehavior
      property :title, multiple:false, predicate: ::RDF::Vocab::DC.title
    end
  }
  after {
    Object.send(:remove_const, :Foo)
  }
  
  let(:clean_object) { Foo.create(dirty_state: 'clean') }
  let(:dirty_object) { Foo.create() }
  
  describe "create" do
    it "sets dirty by default" do
      expect(dirty_object).to be_dirty
      expect(dirty_object).not_to be_clean
    end
    it "can make a clean object" do
      expect(clean_object).not_to be_dirty
      expect(clean_object).to be_clean
    end
  end
  
  describe "save" do
    let(:other_object) { Foo.create }
    it "makes an object dirty" do
      clean_object.title='changed'
      clean_object.save
      expect(clean_object.reload).to be_dirty
    end
    it "makes an object dirty with only member changes" do
      clean_object.ordered_members << other_object
      clean_object.save
      expect(clean_object.reload).to be_dirty
    end
    it "can clean an object" do
      dirty_object.set_clean
      dirty_object.save
      expect(dirty_object.reload).not_to be_dirty
    end
    it "can both modify and keep an object clean" do
      clean_object.ordered_members << other_object
      clean_object.set_clean
      clean_object.save
      expect(clean_object.reload).not_to be_dirty
    end
    it "forces setting dirty_state" do
      other_clean = Foo.find(clean_object.id);
      other_clean.title='changed'
      other_clean.save
      expect(other_clean.reload).to be_dirty
      # clean_object thinks dirty_state=='clean' already but it's 'dirty' in fedora
      clean_object.set_clean
      clean_object.save
      expect(clean_object.reload).not_to be_dirty
    end
  end
  
  describe "update" do
    it "makes an object dirty" do
      clean_object.update(title: 'changed')
      expect(clean_object.reload).to be_dirty
    end
  end
  
  describe "::all_dirty" do
    before { clean_object ; dirty_object } # create by referencing
    let!(:dirty_object2) { Foo.create() }
    let(:res) { Foo.all_dirty.to_a }
    it "finds all dirty objects" do
      expect(res.map(&:id)).to match_array([dirty_object.id,dirty_object2.id])
    end
  end

end