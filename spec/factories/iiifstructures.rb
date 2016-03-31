FactoryGirl.define do
  factory :iiifstructure, class: Trifle::IIIFStructure do

    sequence(:title) { |n| "Structure #{n}" }

    trait :with_manifest do
      after :create do |s, evaluator|
        manifest = FactoryGirl.create(:iiifmanifest)
        manifest.ordered_members << s
        manifest.save
      end
    end
    
    trait :with_canvases do
      after :create do |s, evaluator|
        canvases = [ FactoryGirl.create(:iiifimage), FactoryGirl.create(:iiifimage) ]
        manifest = s.manifest
        manifest.ordered_members += canvases
        s.ordered_members += canvases
        s.save
        manifest.save
      end
    end
    
    trait :with_sub_structure do
      ordered_members {
        [ FactoryGirl.build(:iiifstructure), FactoryGirl.build(:iiifstructure) ]
      }
    end
  end
end
