FactoryGirl.define do
  factory :iiifrange, class: Trifle::IIIFRange do

    sequence(:title) { |n| "Range #{n}" }

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
    
    trait :with_sub_range do
      ordered_members {
        [ FactoryGirl.build(:iiifrange), FactoryGirl.build(:iiifrange) ]
      }
    end
  end
end
