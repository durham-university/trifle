require 'rails_helper'

RSpec.describe Trifle::IIIFImage do
  describe "#as_json" do
    let(:image) { FactoryGirl.build(:iiifimage)}
    let(:json) { image.as_json }
    it "sets properties" do
      expect(json['title']).to be_present
    end
  end  

end
