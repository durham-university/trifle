namespace :trifle do
  desc "creates some test data"
  task "create_test_data" => :environment do
    Trifle::IIIFCollection.create(
      title: 'Durham University Library',
      ordered_members: [
        Trifle::IIIFCollection.create(title: 'Sudan Archive'),
        Trifle::IIIFCollection.create(title: 'Another Sub-Collection'),
      ]
    )
    Trifle::IIIFCollection.create(title: 'Durham Cathedral Library')
    Trifle::IIIFCollection.create(
      title: 'Other Digitised Material',
      ordered_members: [
        Trifle::IIIFCollection.create(title: 'Test Collection 1'),
        Trifle::IIIFCollection.create(title: 'Test Collection 2'),        
      ]
    )
    Trifle::IIIFCollection.all.each do |x| x.update_index end
  end
end
