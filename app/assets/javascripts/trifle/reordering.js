function enableReordering(button, selector, formSelector){
  button = jQuery(button);
  var list = jQuery(selector);
  list.each(function(){
    var item = jQuery(this);
    if(!item.hasClass("ui-sortable")){
      item.sortable();
      item.disableSelection();      
    }
  });
  list.before("<p>Reorder images by by dragging and dropping. Click save button after done. </p>")
  
  button.find('.glyphicon-sort').removeClass('glyphicon-sort').addClass('glyphicon-floppy-saved');
  button.attr('onclick','');
  button.on('click',function(){
    var ids = jQuery(selector).find('li>a').map(function(){
      return jQuery(this).attr('href').split('/').pop();
    }).toArray().join('\n');
    var form = jQuery(formSelector);
    form.find("input[name='iiif_manifest[canvas_order]']").val(ids);
    form.submit();
  });
}
