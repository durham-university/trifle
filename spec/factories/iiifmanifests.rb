FactoryGirl.define do
  factory :iiifmanifest, class: Trifle::IIIFManifest do

    sequence(:title) { |n| "Manifest #{n}" }
    sequence(:image_container_location) { |n| "folder#{n}" }

    trait :with_images do
      ordered_members {
        [ FactoryGirl.build(:iiifimage), FactoryGirl.build(:iiifimage) ]
      }
    end
    
    trait :with_parent do
      after :create do |manifest, evaluator|
        collection = FactoryGirl.create(:iiifcollection)
        collection.ordered_members << manifest
        collection.save
      end
    end
  end
end
