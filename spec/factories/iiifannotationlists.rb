FactoryGirl.define do
  factory :iiifannotationlist, class: Trifle::IIIFAnnotationList do

    sequence(:title) { |n| "Annotation list #{n}" }

    trait :with_image do
      after :create do |al, evaluator|
        image = FactoryGirl.create(:iiifimage)
        image.ordered_members << al
        image.save
      end
    end
    
    trait :with_manifest do
      after :create do |al, evaluator|
        image = FactoryGirl.create(:iiifimage, :with_manifest)
        image.ordered_members << al
        image.save
      end
    end
        
    trait :with_annotations do
      ordered_members {
        [ FactoryGirl.build(:iiifannotation), FactoryGirl.build(:iiifannotation) ]
      }
    end
  end
end
