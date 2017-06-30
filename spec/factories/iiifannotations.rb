FactoryGirl.define do
  factory :iiifannotation, class: Trifle::IIIFAnnotation do

    sequence(:title) { |n| "Image #{n}" }
    sequence(:selector) { |n| "{\"@type\":\"oa:FragmentSelector\",\"value\":\"xywh=100,#{n}00,200,80\"}" }
    format 'text/html'
    language 'en'
    sequence(:content) { |n| "content #{n}"}
    

    trait :with_annotation_list do
      # This is same as with_image. Since annotations and annotaion lists are
      # now entirely stored in the image, you can't really create an annotation
      # and its annotation list alone. For historical reasons there's still the
      # two traits.
      before :create do |annotation, evaluator|
        annotation_list = FactoryGirl.create(:iiifannotationlist,:with_image)
        annotation_list.annotations.push(annotation)
        annotation.parent = annotation_list
      end
    end
    
    trait :with_image do
      before :create do |annotation, evaluator|
        annotation_list = FactoryGirl.create(:iiifannotationlist,:with_image)
        annotation_list.annotations.push(annotation)
        annotation.parent = annotation_list
      end
    end
    
    trait :with_manifest do
      before :create do |annotation, evaluator|
        annotation_list = FactoryGirl.create(:iiifannotationlist,:with_manifest)
        annotation_list.annotations.push(annotation)
        annotation.parent = annotation_list
      end
    end
  end
end
