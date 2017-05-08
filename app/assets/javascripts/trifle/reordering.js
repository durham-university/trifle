function enableReordering(button, selector, formFieldSelector){
  button = jQuery(button);
  var list = jQuery(selector);
  var tag = list.prop('tagName');
  var itemSelector = (tag == 'TABLE' || tag == 'TBODY') ? 'td.item-label>a' : 'li>a';
  list.each(function(){
    var item = jQuery(this);
    if(tag == 'TABLE') item = item.find('>tbody');
    if(!item.hasClass("ui-sortable")){
      item.sortable();
      item.disableSelection();      
    }
  });
  list.before("<p>Reorder images by by dragging and dropping. Click save button after done. </p>")
  
  button.find('.glyphicon-sort').removeClass('glyphicon-sort').addClass('glyphicon-floppy-saved');
  button.attr('onclick','');
  button.on('click',function(){
    var ids = jQuery(selector).find(itemSelector).map(function(){
      return jQuery(this).attr('href').split('/').pop();
    }).toArray().join('\n');
    var field = jQuery(formFieldSelector);
    var form = field.closest('form');
    field.val(ids);
    form.submit();
  });
}
