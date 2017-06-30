require 'rails_helper'

RSpec.describe Trifle::MillenniumActor do
  let(:user) {nil}
  let(:options) { { } }
  let(:manifest) { FactoryGirl.build(:iiifmanifest) }
  let(:actor) { Trifle::MillenniumActor.new(manifest,user,options) }
  before {
    allow(actor).to receive(:default_connection_params).and_return({})
    allow(actor).to receive(:default_remote_path).and_return('/tmp')
    expect(actor).not_to receive(:write_package)
    expect(actor).not_to receive(:send_or_copy_file)
  }

  describe "#upload_package" do
    it "calls millennium_package" do
      expect(actor).to receive(:millennium_package).and_return([])
      actor.upload_package
    end
  end

  describe "#millennium_package" do
    before {
      expect(manifest).to receive(:to_millennium_all).and_return({
        'mid1234' => ['line1', 'line2'],
        'mid5678' => ['line3']
      })
    }
    it "gets all millennium records" do
      package = actor.millennium_package.to_a
      expect(package.length).to eql(2)
      expect(package[0].path).to eql('mid1234')
      expect(package[0].content.to_s).to eql("line1\nline2")
      expect(package[1].path).to eql('mid5678')
      expect(package[1].content.to_s).to eql("line3")
    end
  end

end