FactoryGirl.define do
  factory :iiiflayer, class: Trifle::IIIFLayer do
    transient do 
      image nil
    end

    sequence(:title) { |n| "Layer #{n}"}
    sequence(:description) { |n| "test description #{n}" }
    width '1000'
    height '2000'
    sequence(:image_location) { |n| "folder/layer_image#{n}.ptif" }
    embed_xywh "0,0,1000,2000"

    after :build do |layer,evaluator|
      layer.instance_variable_set(:@container, evaluator.image) if evaluator.image.present?
    end
  end
end