FactoryGirl.define do
  factory :iiifannotationlist, class: Trifle::IIIFAnnotationList do

    sequence(:title) { |n| "Annotation list #{n}" }

    trait :with_image do
      before :create do |al, evaluator|
        image = FactoryGirl.create(:iiifimage)
        image.annotation_lists.push(al)
        al.parent = image
      end
    end
    
    trait :with_manifest do
      before :create do |al, evaluator|
        image = FactoryGirl.create(:iiifimage, :with_manifest)
        image.annotation_lists.push(al)
        al.parent = image
      end
    end
        
    trait :with_annotations do
      after :create do |al, evaluator|
        a = FactoryGirl.build(:iiifannotation, parent: al)
        al.annotations.push(a)
        a.save
        a = FactoryGirl.build(:iiifannotation, parent: al)
        al.annotations.push(a)
        a.save        
      end
    end
  end
end
