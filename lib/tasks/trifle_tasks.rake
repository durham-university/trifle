namespace :trifle do
  desc "create a hidden root collection"
  task "create_hidden_root" => :environment do
    if Trifle.hidden_root_collection_id.present?
      puts "Hidden root collection id is already set in config."
    else
      puts "Creating root collection"
      root = Trifle::IIIFCollection.create(title: "Collection index")
      sub_collections = []
      puts "Moving existing top collections"
      Trifle::IIIFCollection.root_collections.each do |c|
        sub_collections << c unless c.id == root.id
      end
      root.ordered_members = sub_collections
      root.save
      puts "To enable the root collection, add  \"hidden_root_collection_id: #{root.id}\" to config/trifle.yml"
    end
  end

  desc "statify all dirty manifests"
  task "statify_dirty" => :environment do
    if Trifle::StatifyDirtyJob.new.queue_job
      puts "Successfully queued StatifyDirtyJob"
      true
    else
      puts "Unable to queue StatifyDirtyJob"
      false
    end
  end
  
  desc "sets image arks to be child arks of their parents"
  task "image_child_arks" => :environment do
    Trifle::IIIFManifest.all.each do |m|
      puts "Processing manifest #{m.id} #{m.title}"
      parent_ark = m.local_ark
      
      # do a quick check if we need to process this manifest at all
      next unless m.ordered_members.from_solr.any? do |item|
        item.is_a?(Trifle::IIIFImage) && !item.local_ark.start_with?(parent_ark)
      end
      
      m.images.each do |img|
        next if img.local_ark.start_with?(parent_ark)
        img.save if img.update_ark_parents
      end
      
      # Free up memory by nilling some cached variables. Otherwise these for all
      # manifests togetger can grow up enough to cause out of memory error
      m.instance_variable_set(:@ordered_items,nil)
      m.instance_variable_set(:@ordered_item_ids,nil)
      m.ordered_items_serial.instance_variable_set(:@content,nil)
    end
    puts "All done"
  end
  
  desc "outputs a foliation text file"
  task "foliation_file", [:front_count, :main_count, :back_count] do |t,args|
    def roman(n)
      ret = ''
      ret << 'x'*(n/10)
      n = n%10
      ret << 'ix'*(n/9)
      n = n%9
      ret << 'v'*(n/5)
      n = n%5
      ret << 'iv'*(n/4)
      n = n%4
      ret << 'i'*n
      ret
    end
    
    front_count = args[:front_count].to_i
    main_count = args[:main_count].to_i
    back_count = args[:back_count].to_i
    if main_count == 0
      main_count = front_count
      front_count = 0
    end
    unless front_count + main_count + back_count > 0
      puts 'Usage:'
      puts '  bundle exec rake trifle:foliation_file[front_folios,main_folios,back_folios]'
    else
      (1..(front_count)).each do |n|
        r = roman(n)
        puts("f.#{r} r")
        puts("f.#{r} v")
      end
      (1..(main_count)).each do |n|
        puts("f.#{n}r")
        puts("f.#{n}v")
      end
      (1..(back_count)).each do |n|
        r = roman(n+front_count)
        puts("f.#{r} r")
        puts("f.#{r} v")
      end
    end
  end
end
