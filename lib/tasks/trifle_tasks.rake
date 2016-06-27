namespace :trifle do
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
end
