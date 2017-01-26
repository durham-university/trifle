module Trifle
  class UpdateRangesActor < BaseActor
    def initialize(model_object, user=nil, attributes={})
      super(model_object, user, attributes)
      @translate_canvases = attributes.fetch(:translate_canvases, false)
      @iiif_version = attributes.fetch(:iiif_version, 'auto')
    end
    
    def update_ranges(ranges_json)
      if ['1','auto'].include?(@iiif_version.to_s)
        ranges_json = adapt_json(ranges_json)
      end
      
      existing_ranges = {}
      collect_ranges = lambda do |range|
        existing_ranges[range.id] = range
        range.sub_ranges.each(&collect_ranges)
      end
      @model_object.ranges.each(&collect_ranges)
      
      if @translate_canvases
        top_range = ranges_json.find do |range| range['viewingHint'] == 'top' end
        unless top_range
          log!(:error, "Ranges json doesn't contain a top range. Can't build a canvas map.")
          return false
        end
        json_canvas_ids = (top_range['canvases'] || []).map do |uri| extract_id(uri) end
        unless json_canvas_ids.length == @model_object.images.length
          log!(:error, "Number of canvases in json and existing range don't match.")
          return false
        end
        canvas_map = json_canvas_ids.zip(@model_object.images.to_a).each_with_object({}) do |(json_id,img),map|
          map[json_id] = img.id
        end
      else
        # no mapping, create identity map
        canvas_map = @model_object.images.each_with_object({}) do |img,map| map[img.id] = img.id end
      end
      existing_canvases = @model_object.images.each_with_object({}) do |img,map| map[img.id] = img end
      
      # ranges that need to be destroyed, but don't do it until everything else
      # is done
      delete_ranges = existing_ranges.keys - (ranges_json.map do |range_json| extract_id(range_json['@id']) end)
      
      # create new ranges
      ranges_json.each do |range_json|
        range_id = extract_id(range_json['@id'])
        unless existing_ranges.key?(range_id)
          existing_ranges[range_id] = Trifle::IIIFRange.new(@model_object, title: (range_json['label'] || 'New range'))
          existing_ranges[range_id].assign_id!
          @model_object.ranges << existing_ranges[range_id] if range_json['viewingHint'] == 'top'
        end
      end
      
      ranges_json.each do |range_json|
        # set range metadata
        range = existing_ranges[extract_id(range_json['@id'])]
        range.title = range_json['label']
        
        new_range_ids = (range_json['ranges'] || []).map(&method(:extract_id))
        new_canvas_ids = (range_json['canvases'] || []).map do |uri|
          id = canvas_map[extract_id(uri)]
          log!(:error, "Couldn't map canvas id #{extrect_id(uri)} to an existing canvas") unless id
          id
        end
        
        # set range structure
        unless range.sub_range_ids == new_canvas_ids && range.canvas_ids == new_range_ids
           new_ranges = new_range_ids.map do |id| existing_ranges[id] end
           new_canvases = new_canvas_ids.map do |id| existing_canvases[id] end
           range.canvases = new_canvases
           range.sub_ranges = new_ranges
        end
      end      

      # delete ranges
      delete_ranges.each do |delete_id|
        # Only need to delete if top range. Other ranges should already be
        # removed from the tree and won't get serialised and saved
        @model_object.ranges.delete(existing_ranges[delete_id])
        existing_ranges.delete(delete_id)
      end
      
      # save
      @model_object.serialise_ranges
      @model_object.save
      # save returns true or false
    end
    
    private 
    
      def adapt_json(ranges_json)
        range_index = ranges_json.each_with_object({}) do |range,index|
          index[range['@id']] = range
        end
        ranges_json.each do |range|
          if range['within'].present?
            within = range_index[range['within']]
            within['ranges'] ||= []
            within['ranges'].push(range['@id']) unless within['ranges'].include?(range['@id'])
          end
        end
        ranges_json
      end
    
      def extract_id(uri)
        uri.split('/').last
      end
  end
end