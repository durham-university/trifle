module Trifle
  module MemberReordering
    extend ActiveSupport::Concern
    
    protected
    
    def reorder_members(params_order,item_class)
      split = params_order.split(/[\r\n]+/)
      new_item_ids = split.uniq
      return false if new_item_ids.length != split.length
      
      new_items = []
      non_items = []
      item_index = {}
      @resource.ordered_members.to_a.each do |m| 
        if m.is_a?(item_class)
          item_index[m.id] = m
        else
          non_items << m
        end
      end
      return false if item_index.length != new_item_ids.length
      
      new_item_ids.each do |item_id|
        item = item_index[item_id]
        break unless item
        new_items << item
      end      
      return false if new_items.length != item_index.length
      
      @resource.ordered_members = new_items + non_items
      true      
    end
  end
end