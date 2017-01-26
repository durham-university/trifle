FactoryGirl.define do
  factory :iiifrange, class: Trifle::IIIFRange do

    sequence(:title) { |n| "Range #{n}" }

    trait :with_manifest do
      before :create do |s, evaluator|
        manifest = FactoryGirl.create(:iiifmanifest)
        manifest.ranges.push(s)
        s.manifest = manifest
      end
    end
    
    trait :with_canvases do
      after :create do |s, evaluator|
        canvases = [ FactoryGirl.create(:iiifimage), FactoryGirl.create(:iiifimage) ]
        manifest = s.manifest
        manifest.ordered_members << canvases[0]
        manifest.ordered_members << canvases[1]
        manifest.save
        s.canvases.push(*canvases)
        s.save
      end
    end
    
    trait :with_sub_range do
      after :create do |s, evaluator|
        r = FactoryGirl.build(:iiifrange, manifest: s.manifest)
        s.sub_ranges.push(r)
        r.save
        r = FactoryGirl.build(:iiifrange, manifest: s.manifest)
        s.sub_ranges.push(r)
        r.save
      end
    end
  end
end
