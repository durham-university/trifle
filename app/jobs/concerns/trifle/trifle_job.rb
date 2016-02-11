module Trifle::TrifleJob
  extend ActiveSupport::Concern

  def queue
    Trifle.queue
  end
end
