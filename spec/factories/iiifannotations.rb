FactoryGirl.define do
  factory :iiifannotation, class: Trifle::IIIFAnnotation do

    sequence(:title) { |n| "Image #{n}" }
    sequence(:selector) { |n| "{\"@type\" : \"oa:FragmentSelector\", \"value\" : \"xywh=100,#{n}00,200,80\" }" }
    format 'text/html'
    language 'en'
    sequence(:content) { |n| "content #{n}"}
    

    trait :with_annotation_list do
      after :create do |annotation, evaluator|
        annotation_list = FactoryGirl.create(:iiifannotationlist)
        annotation_list.ordered_members << annotation
        annotation_list.save
      end
    end
    
    trait :with_image do
      after :create do |annotation, evaluator|
        annotation_list = FactoryGirl.create(:iiifannotationlist,:with_image)
        annotation_list.ordered_members << annotation
        annotation_list.save
      end
    end
    
    trait :with_manifest do
      after :create do |annotation, evaluator|
        annotation_list = FactoryGirl.create(:iiifannotationlist,:with_manifest)
        annotation_list.ordered_members << annotation
        annotation_list.save
      end
    end
  end
end
