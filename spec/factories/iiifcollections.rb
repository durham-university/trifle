FactoryGirl.define do
  factory :iiifcollection, class: Trifle::IIIFCollection do

    sequence(:title) { |n| "Collection #{n}" }

    trait :with_manifests do
      after :build do |collection|
        ms = FactoryGirl.build(:iiifmanifest), FactoryGirl.build(:iiifmanifest)
        ms.each do |m| collection.ordered_members << m end
        ms.each do |m| m.save end
      end
    end
    
    trait :with_sub_collections do
      after :build do |collection|
        ms = FactoryGirl.build(:iiifcollection), FactoryGirl.build(:iiifcollection)
        ms.each do |m| collection.ordered_members << m end
        ms.each do |m| m.save end
      end
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
