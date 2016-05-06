(function($){
  $.TrifleEndpoint = function(options) {
    jQuery.extend(this, {
      trifleManifestId: null,
      trifleUrlBase: 'http://localhost:3000/trifle/iiif/',
      dfd: null,
      annotationsList: [],
      windowID: null,
      parent: null
    }, options);
    
    this.init();
  };
  
  $.TrifleEndpoint.prototype = {
    init: function(){
    },
    
    set: function(prop, value, options) {
      if (options) {
        this[options.parent][prop] = value;
      } else {
        this[prop] = value;
      }
    },
    
    userAuthorize: function(action, annotation) {
      return true;
    },
    
    addCsrf: function(xhr){
      xhr.setRequestHeader('X-CSRF-Token', jQuery('meta[name="csrf-token"]').attr('content'));
    },
    
    searchUrl: function(canvasUri){
      var canvasId = this.canvasId(canvasUri);
      return this.trifleUrlBase+"manifest/_/canvas/"+canvasId+"/all_annotations";
    },
    annotationUrl: function(annotationUri){
      if(annotationUri.startsWith(this.trifleUrlBase))
        return this.canvasUrl(annotationUri); // same processing
      else {
        // convert id to url, and process like canvas uri
        return this.canvasUrl(this.trifleUrlBase+"manifest/_/annotation/"+annotationUri);
      }
    },
    annotationId: function(annotationUri){
      if(annotationUri.startsWith(this.trifleUrlBase))
        return annotationUri.substring(this.trifleUrlBase.length).split('/')[4];
      else return annotationUri;
    },
    canvasUrl: function(canvasUri){
      var ind = canvasUri.indexOf("#");
      if(ind>=0) canvasUri = canvasUri.substring(0, ind);
      canvasUri = canvasUri.replace('/iiif/manifest/','/manifest/')
      return canvasUri;
    },
    canvasId: function(canvasUri){
      return canvasUri.substring(this.trifleUrlBase.length).split('/')[4];
    },
    
    search: function(options, successCallback, errorCallback){
      var _this = this;
      this.annotationsList = [];
      
      jQuery.ajax({
        url: this.searchUrl(options['uri']),
        beforeSend: this.addCsrf,
        type: 'GET',
        dataType: 'json',
        success: function(data){
          if (typeof successCallback === "function") successCallback(data);
          else {
            jQuery.each( data, function(index, value) {
              _this.annotationsList.push(_this.toOa(value));
            })
            _this.dfd.resolve(true);
          }
        },
        error: function(){
          if (typeof errorCallback === "function") errorCallback();
          else console.log("Error searching Trifle annotation endpoint");
        }
      });
    },
    
    deleteAnnotation: function(annotationUri, successCallback, errorCallback) {
      var id = this.annotationId(annotationUri);
      var _this = this;
      jQuery.ajax({
        url: this.annotationUrl(annotationUri),
        beforeSend: this.addCsrf,
        type: 'DELETE',
        dataType: 'json',
        success: function(data) {
          if (typeof successCallback === "function") successCallback(_this.annotationId(annotationUri));
        },
        error: function() {
          if (typeof errorCallback === "function") errorCallback();          
        }
      });
    },
    
    update: function(oaAnnotation, successCallback, errorCallback) {
      var _this = this;
      
      var params = this.annotationParams(oaAnnotation);
      if(!params) {
        if(errorCallback) errorCallback();
        return;
      }
      
      jQuery.ajax({
        url: this.annotationUrl(oaAnnotation['@id']),
        beforeSend: this.addCsrf,
        type: 'PUT',
        dataType: 'json',
        data: params,
        success: function(data) {
          if (typeof successCallback === "function") successCallback(data);
        },
        error: function() {
          if (typeof errorCallback === "function") errorCallback();          
        }        
      });
    },
    
    create: function(oaAnnotation, successCallback, errorCallback) {
      var _this = this;
      
      var params = this.annotationParams(oaAnnotation);
      if(!params) {
        if(errorCallback) errorCallback();
        return;
      }
      
      jQuery.ajax({
        url: this.canvasUrl(oaAnnotation['on']['full'])+'/annotation',
        beforeSend: this.addCsrf,
        type: 'POST',
        dataType: 'json',
        data: params,
        success: function(data) {
          if (typeof successCallback === "function") successCallback(_this.toOa(data));
        },
        error: function() {
          if (typeof errorCallback === "function") errorCallback();          
        }
      });
    },
  
    toOa: function(record) {
      record['@id'] = this.annotationId(record['@id']);
      record['resource'] = [record['resource']];
      record['endpoint'] = this;
      return record;
    },
    
    annotationParams: function(oaAnnotation) {
      var contentResource = null;
      jQuery.each(oaAnnotation.resource, function(index, value){
        if(value['@type'] == 'dctypes:Text' || value['@type'] == 'cnt:ContentAsText')
          contentResource = value;
        // type could also be 'oa:Tag', not handled in trifle yet
      });
      
      if(!contentResource) {
        console.log("Couldn't resolve content resource for Trifle endpoint update");
        return null
      }
      
      var content = contentResource['chars'];
      var title = content;
      if(title.startsWith('<')) title = jQuery(content).text();
      if(title.length > 20) title = title.substring(0,20)+"...";
      
      if(typeof(oaAnnotation['on'])=='string') {
        var ind = oaAnnotation['on'].indexOf('#');
        var fragment = oaAnnotation['on'].substring(ind+1);
        oaAnnotation['on']={value: fragment};
        oaAnnotation['on']['@type'] = 'oa:FragmentSelector';
      }
      
      return {
        reply_iiif: true,
        'iiif_annotation[title]' : title,
        'iiif_annotation[content]' : content,
        'iiif_annotation[format]' : contentResource['format'],
        'iiif_annotation[selector]' : JSON.stringify(oaAnnotation['on']['selector']),
        'iiif_annotation[language]' : contentResource['language'],
      };
    },
  };
  
}(Mirador));