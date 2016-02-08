$(function(){
  $('.iipmooviewer_container').each(function(){
    var containerDiv = $(this);
    var server = containerDiv.find('.viewer_server').text();
    var image = containerDiv.find('.viewer_image_path').text();
    var viewer = $('<div class="viewer"></div>')
    containerDiv.append(viewer)
    var mooViewer = new IIPMooViewer( viewer[0], {
      server: server,
      image: image,
      protocol: 'IIP',
      prefix: '/assets/iipmooviewer/'
    });
  });
});
