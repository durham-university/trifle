require 'rails_helper'

RSpec.describe Trifle::ArkNaanOptionsBehaviour do
  before {
    module FooNamespace
      def self.config
        {'ark_naan' => '11111', 'allowed_ark_naan' => ['11111','22222','33333']}
      end
    end
    class FooNamespace::TestObject < ActiveFedora::Base
      include Trifle::ArkNaanOptionsBehaviour
      property :title, predicate: ::RDF::DC.title, multiple: false
      property :identifier, predicate: ::RDF::DC.identifier do |index|
        index.as :symbol
      end
      def id_mint_service
        @minter ||= Minter.new
      end
      class Minter
        def mint
          SecureRandom.hex
        end
      end
    end
  }
  after {
    Object.send(:remove_const,:FooNamespace)
  }
  let(:new_params) { nil }
  let(:resource) { FooNamespace::TestObject.new(new_params) }

  describe "::create" do
    it "can set a custom naan" do
      obj = FooNamespace::TestObject.create(title: 'ark test')
      expect(obj.local_ark).to start_with('ark:/11111/')
      expect(obj.title).to eql('ark test')
      obj = FooNamespace::TestObject.create(title: 'ark test 2', ark_naan: '22222')
      expect(obj.local_ark).to start_with('ark:/22222/')
      expect(obj.title).to eql('ark test 2')
    end
  end
  
  describe "#allowed_ark_naan" do
    it "returns what's in config" do
      allow(FooNamespace).to receive(:config).and_return({'ark_naan' => '11111', 'allowed_ark_naan' => ['11111','22222']})
      expect(resource.allowed_ark_naan).to eql(['11111','22222'])
    end
    it "always includes ark_naan" do
      allow(FooNamespace).to receive(:config).and_return({'ark_naan' => '11111', 'allowed_ark_naan' => ['22222']})
      expect(resource.allowed_ark_naan).to match_array(['11111','22222'])
    end
    it "works with nil in config" do
      allow(FooNamespace).to receive(:config).and_return({'ark_naan' => '11111'})
      expect(resource.allowed_ark_naan).to eql(['11111'])
    end
  end

  describe "#assign_new_ark" do
    let(:ark_naan) { '11111' }
    let(:id) { 'abcdefgh' }
    before {
      allow(resource.class).to receive(:ark_naan).and_return(ark_naan)
      allow(resource).to receive(:id_mint_service).and_return(
        double('id mint service', mint: id)
      )
    }
    
    context "when no naan set" do
      it "sets uses default naan" do
        resource.assign_new_ark
        expect(resource.identifier).to match_array(["ark:/#{ark_naan}/#{id}"])        
      end
    end
    context "when naan is set" do
      before { resource.set_ark_naan('22222') }
      it "uses set naan" do
        resource.assign_new_ark
        expect(resource.identifier).to match_array(["ark:/22222/#{id}"])        
      end
    end
  end
  
  describe "#id_from_ark" do
    before { 
      resource.set_ark_naan('22222')
      resource.instance_variable_set(:@minted_ark_id,'ark:/22222/abcdefgh') 
    }
    it "works with set naan" do
      expect(resource.id_from_ark).to eql('abcdefgh')
    end
  end
  
  describe "#local_ark" do
    it "gets arks with set naans" do
      resource.identifier = ['doi:other', 'ark:/00000/abc', 'ark:/33333/def']
      expect(resource.local_ark).to eql('ark:/33333/def')
    end
    it "ignores naans that aren't allowed" do
      resource.identifier = ['doi:other', 'ark:/00000/abc']
      expect(resource.local_ark).to be_nil
    end
    it "returns any ark if * naan allowed" do
      allow(FooNamespace).to receive(:config).and_return({'ark_naan' => '11111', 'allowed_ark_naan' => ['*']})
      resource.identifier = ['doi:other', 'ark:/33333/def', 'ark:/00000/abc']
      expect(resource.local_ark).to eql('ark:/00000/abc')
    end
  end
  
  describe "#local_ark_naan" do
    it "returns naan of local_ark" do
      expect(resource).to receive(:local_ark).and_return('ark:/44444/abcd')
      expect(resource.local_ark_naan).to eql('44444')
    end
  end
  
  describe "#set_ark_naan" do
    it "sets naan if in allowed list" do
      expect(resource.ark_naan).to eql('11111')
      resource.set_ark_naan('22222')
      expect(resource.ark_naan).to eql('22222')
    end
    it "refuses naan if not in allowed list" do
      expect {
        resource.set_ark_naan('44444')
      } .to raise_error("Invalid naan 44444")
    end
    it "allows any naan if * in allowed list" do
      allow(FooNamespace).to receive(:config).and_return({'ark_naan' => '11111', 'allowed_ark_naan' => ['*']})
      resource.set_ark_naan('44444')
      expect(resource.ark_naan).to eql('44444')
    end
    it "can set nil naan" do
      resource.set_ark_naan('22222')
      resource.set_ark_naan(nil)
      expect(resource.ark_naan).to eql('11111')
    end
  end

end