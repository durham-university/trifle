FactoryGirl.define do
  factory :iiifcollection, class: Trifle::IIIFCollection do

    sequence(:title) { |n| "Collection #{n}" }

    trait :with_manifests do
      ordered_members {
        [ FactoryGirl.build(:iiifmanifest), FactoryGirl.build(:iiifmanifest) ]
      }
    end

    trait :with_parent do
      after :create do |collection, evaluator|
        parent = FactoryGirl.create(:iiifcollection)
        parent.ordered_members << collection
        parent.save
      end
    end
    
  end
end
