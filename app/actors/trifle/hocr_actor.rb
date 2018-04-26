module Trifle
  class HOCRActor < Trifle::BaseActor

    def initialize(model_object, user=nil, attributes={})
      super(model_object, user, attributes)
      @hocr_files = attributes[:hocr_files]
      @canvas_offset = attributes.fetch(:canvas_offset, 0).to_i
      @canvas_scale = attributes.fetch(:canvas_scale, :auto)
      @transform_matrix = attributes.fetch(:transform_matrix, nil)
      @language = attributes.fetch(:language, nil)
      @page_annotations = attributes.fetch(:page_annotations, true)
      @annotation_lists = {}
    end

    def process_files
      @hocr_files.each do |file|
        process_file(file)
      end
    end

    def transform_matrix_for(canvas, title)
      if @transform_matrix && @transform_matrix != :auto
        if @transform_matrix.respond_to?(:call)
          transform_matrix = @transform_matrix.call(canvas, title)
        else
          transform_matrix = @transform_matrix
        end
      elsif @canvas_scale == :auto || @transform_matrix == :auto
        ocr_page_size = title['bbox'].split(' ')[2..3].map(&:to_f)
        transform_matrix = [canvas.width.to_f/ocr_page_size[0], 0.0, 0.0,
                            0.0, canvas.height.to_f/ocr_page_size[1], 0.0]
      else
        transform_matrix = [@canvas_scale || 1.0, 0.0, 0.0, 0.0, @canvas_scale || 1.0, 0.0]
      end
    end

    def transform_bbox(bbox, matrix)
      [
        bbox[0]*matrix[0] + bbox[1]*matrix[1] + matrix[2],
        bbox[0]*matrix[3] + bbox[1]*matrix[4] + matrix[5],
        bbox[2]*matrix[0] + bbox[3]*matrix[1] + matrix[2],
        bbox[2]*matrix[3] + bbox[3]*matrix[4] + matrix[5],
      ]
    end

    def process_file(file)
      xml = Nokogiri::XML(File.read(file))
      xml.remove_namespaces!
      xml.xpath("//div[@class='ocr_page']").each do |page_elem|
        page_text = page_elem.text()
        title = parse_title(page_elem)
        canvas = canvas_for(file, title['image'])
        next unless canvas.present?
        annotation_list = annotation_list_for(canvas)

        transform_matrix = transform_matrix_for(canvas, title)

        # page and line_selectors are x1,y1,x2,y2 isntead of x,y,w,h in hocr.
        # They are converted to x,y,w,h just before being added to annotations
        page_selector = [nil, nil, nil, nil]
        page_elem.xpath(".//span[@class='ocr_line']").each do |line_elem|
          line_text = line_elem.text()
          line_title = parse_title(line_elem)
          line_selector = line_title['bbox'].split(' ').map(&:to_i)

          # figure out maximum extents for page selector
          page_selector[0] = line_selector[0] if page_selector[0].nil? || page_selector[0] > line_selector[0]
          page_selector[1] = line_selector[1] if page_selector[1].nil? || page_selector[1] > line_selector[1]
          page_selector[2] = line_selector[2] if page_selector[2].nil? || page_selector[2] < line_selector[2]
          page_selector[3] = line_selector[3] if page_selector[3].nil? || page_selector[3] < line_selector[3]

          line_selector = transform_bbox(line_selector, transform_matrix)
          # change from x1,y1,x2,y2 to x,y,w,h
          line_selector[2] = line_selector[2] - line_selector[0]
          line_selector[3] = line_selector[3] - line_selector[1]

          line_selector.map! do |x| x.round end
  
          create_annotation(annotation_list, line_text, "xywh=#{line_selector.join(',')}")
        end

        unless page_selector.any?(&:nil?) || !@page_annotations
          page_selector = transform_bbox(page_selector, transform_matrix)
          # change from x1,y1,x2,y2 to x,y,w,h
          page_selector[2] = page_selector[2] - page_selector[0]
          page_selector[3] = page_selector[3] - page_selector[1]
          
          page_selector.map! do |x| x.round end

          create_annotation(annotation_list, page_text, "xywh=#{page_selector.join(',')}")
        end
      end
    end

    def save_annotations
      @annotation_lists.values.each do |al|
        canvas = al.parent
        canvas.annotation_lists.push(al) unless canvas.annotation_lists.include?(al)
        al.save # this serialises the list and saves the canvas
      end
    end

    def create_annotation(list, content, selector)
      selector = Trifle::IIIFAnnotation.fragment_selector(selector) if selector.start_with?('xywh=')
      Trifle::IIIFAnnotation.new(list, 
        title: annotation_title(content),
        format: 'text/plain',
        language: @language,
        content: content,
        selector: selector
      ).tap do |a| 
        a.assign_id!
        list.annotations << a 
      end
    end

    def annotation_title(content)
      if content.length > 15
        "#{content[0..15]}..."
      else
        content
      end
    end

    def canvas_for(source_file, page_file=nil)
      [page_file, source_file].compact.each do |file_name|
        file_name = file_name.split('.')[0..-2].join('.') #removes extension
        parts = file_name.split(/[\.\/_-]/).reverse
        parts.each do |part|
          m = part.match(/^\d+$/)
          if m
            canvas_index = part.to_i + @canvas_offset
            return nil if canvas_index < 0
            return @model_object.images[canvas_index]
          end
        end
      end
      return nil
    end

    def annotation_list_for(canvas)
      @annotation_lists[canvas.id] ||= Trifle::IIIFAnnotationList.new(canvas, title: 'OCR')
    end

    def parse_title(elem)
      elem['title'].split(';').each_with_object({}) do |s,o| k,v=s.split(' ',2); o[k]=v end
    end
  
  end
end