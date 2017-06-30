module Trifle
  class MillenniumActor < Trifle::BaseActor
    include DurhamRails::Actors::SFTPUploader
    include DurhamRails::Actors::FileCopier
    include Trifle::PackageUpload

    def initialize(model_object, user=nil, attributes={})
      super(model_object, user, attributes)
    end
    
    def upload_package(package=nil, connection_params=nil, remote_path=nil)
      super(package || millennium_package, connection_params, remote_path)
    end
    
    def write_package(root_dir, package=nil)
      super(root_dir, package || millennium_package)
    end
    
    def default_package_label
      "Millennium package for #{model_object.title} (#{model_object.id})"
    end
    
    def millennium_package(target=nil)
      target ||= model_object
      Enumerator.new do |yielder|
        target.to_millennium_all.each do |mid,lines|
          yielder << Trifle::PackageUpload::FileEntry.new(mid, lines.join("\n"))
        end
      end
    end
    
    protected
    
    def default_connection_params
      Trifle.config['millennium_linking_config'].symbolize_keys.except(:root)
    end
    
    def default_remote_path
      Trifle.config['millennium_linking_config'].symbolize_keys[:root]
    end
    
  end
end
