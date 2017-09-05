FactoryGirl.define do
  factory :iiifimage, class: Trifle::IIIFImage do

    sequence(:title) { |n| "Image #{n}" }
    sequence(:image_location) { |n| "folder/image#{n}.ptif" }
    width '1000'
    height '800'

    trait :with_manifest do
      after :create do |image, evaluator|
        manifest = FactoryGirl.create(:iiifmanifest) 
        manifest.ordered_members << image
        manifest.save
      end
    end
  end
end
