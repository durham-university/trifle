module Trifle
  class BackgroundJobsController < Trifle::ApplicationController
    include DurhamRails::BackgroundJobsControllerBehaviour
  end
end