FactoryGirl.define do
  factory :iiifmanifest, class: Trifle::IIIFManifest do

    sequence(:title) { |n| "Manifest #{n}" }
    sequence(:image_container_location) { |n| "folder#{n}" }

    transient do 
      num_images 2
    end

    trait :with_images do
      after :build do |manifest, evaluator|
        (1..(evaluator.num_images)).each do |num|
          manifest.ordered_members.push(FactoryGirl.build(:iiifimage))
        end
      end
    end

    trait :with_range do
      after :create do |manifest|
        r = FactoryGirl.build(:iiifrange, manifest: manifest)
        manifest.ranges.push(r)
        r.save
      end
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
