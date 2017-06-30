module Trifle
  module PackageUpload
    extend ActiveSupport::Concern
    
    def upload_package(package, connection_params=nil, remote_path=nil)
      log!("Uploading #{package.try(:label) || default_package_label}")
      connection_params ||= default_connection_params
      remote_path ||= default_remote_path
      package.each do |file_entry|
        full_path = File.join(remote_path,file_entry.path)
        log!("Sending file #{full_path}")
        return false unless send_or_copy_file(StringIO.new(file_entry.content), full_path, connection_params.reverse_merge(create_dirs: true))
      end
      yield if block_given?
      log!("Done")
      true
    end
    
    def write_package(root_dir, package)
      log!("Writing #{package.try(:label) || default_package_label}")
      package.each do |file_entry|
        full_path = File.join(root_dir, file_entry.path)
        log!("Writing file #{full_path}")
        dir_name = File.dirname(full_path)
        FileUtils.mkdir_p(dir_name)
        File.open(full_path,'wb') do |file|
          file.write(file_entry.content)
        end
      end
      yield if block_given?
      log!("Done")
      true
    end    
    
    def send_or_copy_file(source, dest_path, connection_params)
      if connection_params[:local_copy].to_s == 'true'
        return copy_file_local(source, dest_path, connection_params)
      else
        return send_file(source, dest_path, connection_params.except(:local_copy))
      end
    end    
    
    protected
    
    def default_connection_params
      raise 'Override this'
    end
    
    def default_remote_path
      raise 'Override this'
    end
    
    def default_package_label
      # Override to have more informative labels. Alternatively, make the 
      # package respond to #label. You can use the FilePackage and EnumFilePackage
      # classes for this.
      'package'
    end
        
    class FilePackage < Array
      attr_accessor :label
      def initialize(label, *args)
        self.label = label
        super(*args)
      end
    end
    
    class EnumFilePackage < Enumerator
      attr_accessor :label
      def initialize(label, &block)
        self.label = label
        super(&block)
      end      
    end
    
    class FileEntry
      attr_accessor :path, :content
      def initialize(path,content=nil)
        self.path = path
        self.content = content
      end
    end
    
  end
end