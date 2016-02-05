FactoryGirl.define do
  factory :iiifmanifest, class: Trifle::IIIFManifest do

    sequence(:title) { |n| "Manifest #{n}" }
    sequence(:image_container_location) { |n| "folder#{n}" }

    trait :with_images do
      ordered_members {
        [ FactoryGirl.build(:iiifimage), FactoryGirl.build(:iiifimage) ]
      }
    end
  end
end
