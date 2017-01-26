module Trifle
  class TEIRangeBuilderActor < Trifle::BaseActor
    def initialize(*args)
      super(*args)
    end
    
    def build_range(clear=false)
      range_items = parse_range
      match_parsed(range_items)
      clear_ranges if clear
      build_new_range(range_items)
    end
    
    def clear_ranges()
      @model_object.ranges = []
      @model_object.serialise_ranges
      @model_object.save
    end
    
    def build_new_range(items, parent=nil)
      parent ||= begin
        r = Trifle::IIIFRange.new(@model_object)
        @model_object.ranges << r
        r.assign_id!
        r
      end
      items.each do |item|
        range = Trifle::IIIFRange.new(@model_object, title: item.title)
        range.assign_id!
        if parent.is_a?(Trifle::IIIFManifest)
          parent.ranges << range
        else
          parent.sub_ranges << range
        end
        range.canvases = item.refs
        build_new_range(item.sub_entries, range) # this also saves range
      end
      @model_object.save
      parent
    end
    
    def match_parsed(items)
      items.each do |item|
        images = model_object.images.to_a
        from_ind = images.index do |image| normalise_foliation(image.title) == item.from end
        to_ind = images.index do |image| normalise_foliation(image.title) == item.to end
        item.refs = images[from_ind..to_ind] if from_ind && to_ind
        match_parsed(item.sub_entries)
      end
    end
    
    def tei_record
      @tei_record ||= begin
        if @model_object.source_type == 'schmit'
          schmit_id, item_id = @model_object.source_identifier.split('#',2)
          record = Schmit::API::Catalogue.try_find(schmit_id)
          xml_record = record.try(:xml_record)
          if xml_record
            item_id.nil? ? xml_record : xml_record.sub_item(item_id)
          else
            nil
          end
        end
      end
    end
    
    def normalise_foliation(f)
      m = /^\s*f?\s*\.?\s*(\d+)\s*(r|v)\s*$/i.match(f)
      return f.strip unless m
      "f.#{m[1]}#{m[2].downcase}"
    end
    
    def parse_range(item=nil)
      item ||= tei_record
      item.child_items.map do |child|
        locus = child.locus.try(:strip)
        from, to = locus.try(:split,'-').try(:map) do |f|
          normalise_foliation(f)
        end
        sub_entries = parse_range(child)
        ParsedRangeEntry.new(title: child.title, from: from, to: to, sub_entries: sub_entries)
      end
    end
    
    class ParsedRangeEntry
      attr_accessor :title, :from, :to, :sub_entries, :refs
      def initialize(title: nil, from: nil, to: nil, sub_entries: nil)
        self.title = title
        self.from = from
        self.to = to
        self.sub_entries = Array.wrap(sub_entries) || []
        self.refs = []
      end
    end
    
  end
end