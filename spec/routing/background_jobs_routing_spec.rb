require "rails_helper"

RSpec.describe Trifle::BackgroundJobsController, type: :routing do
  describe "routing" do
    routes { Trifle::Engine.routes }

    it "routes to #show" do
      expect(:get => "/background_jobs/1").to route_to("trifle/background_jobs#show", :id => "1")
    end

    it "routes to #index" do
      expect(get: "/manifest/1/background_jobs").to route_to("trifle/background_jobs#index", resource_id: '1')
    end
    
    it "routes to #rerun_job" do
      expect(post: "/background_jobs/1/rerun_job").to route_to("trifle/background_jobs#rerun_job", id: '1')
    end

  end
end
