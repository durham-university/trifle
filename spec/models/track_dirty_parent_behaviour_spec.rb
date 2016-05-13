require 'rails_helper'

RSpec.describe Trifle::TrackDirtyParentBehaviour do

  before {
    class Foo < ActiveFedora::Base
      include Trifle::TrackDirtyStateBehaviour      
      include Hydra::Works::WorkBehavior
      property :title, multiple:false, predicate: ::RDF::Vocab::DC.title
    end
    class Bar < ActiveFedora::Base
      include Trifle::TrackDirtyParentBehaviour      
      include Hydra::Works::WorkBehavior
      property :title, multiple:false, predicate: ::RDF::Vocab::DC.title
      def parents
        ordered_by
      end
    end
  }
  after {
    Object.send(:remove_const, :Foo)
  }
  
  let(:clean_parent) { Foo.create(dirty_state: 'clean') }
  let(:dirty_parent) { Foo.create() }
  let(:clean_child) { 
    Bar.create().tap do |o| 
      clean_parent.ordered_members << o
      clean_parent.set_clean
      clean_parent.save
    end .reload
  }
  let(:dirty_child) { 
    Bar.create().tap do |o| 
      dirty_parent.ordered_members << o
      dirty_parent.save
    end .reload
  }
  let(:clean_grand_child) {
    Bar.create.tap do |o|
      clean_child.ordered_members << o
      clean_child.save
      clean_parent.set_clean
      clean_parent.save
    end .reload
  }
  
  it "handles base cases" do
    # make sure that the test objects behave as expected
    expect(clean_parent).not_to be_dirty
    expect(dirty_parent).to be_dirty
    clean_child # create by referencing
    dirty_child
    expect(clean_parent).not_to be_dirty
    expect(dirty_parent).to be_dirty
    expect(clean_parent.reload).not_to be_dirty
    expect(dirty_parent.reload).to be_dirty
    clean_grand_child
    expect(clean_parent.reload).not_to be_dirty
  end
  
  describe "save" do
    it "marks parent dirty when changing child" do
      clean_child.title='changed'
      clean_child.save
      expect(clean_parent.reload).to be_dirty
    end
    it "marks parent dirty when changing grand child" do
      clean_grand_child.title='changed'
      clean_grand_child.save
      expect(clean_parent.reload).to be_dirty
    end
    it "marks parent dirty when adding a new grand child" do
      clean_child.ordered_members << Bar.create
      clean_child.save
      expect(clean_parent.reload).to be_dirty
    end
  end
  
  describe "update" do
    it "marks parent dirty when updating child" do
      clean_child.update(title: 'changed')
      expect(clean_parent.reload).to be_dirty
    end
  end
  
  describe "destroy" do
    it "marks parent dirty after destroy" do
      clean_grand_child.destroy
      expect(clean_parent.reload).to be_dirty
      clean_parent.set_clean
      clean_parent.save
      clean_child.reload.destroy
      expect(clean_parent.reload).to be_dirty
    end
  end

end