NK.supportedCRS = ['EPSG:32633','EPSG:25833','urn:ogc:def:crs:EPSG::32633','urn:ogc:def:crs:EPSG::25833'];

NK.functions.getWMSCapabilities = function (url) {
  return NK.functions.corsRequest(url, {"service":"WMS", "request":"GetCapabilities"});
};
NK.functions.getWFSCapabilities = function (url) {
  return NK.functions.corsRequest(url, {"service":"WFS", "request":"GetCapabilities"});
};
NK.functions.getWCSCapabilities = function (url) {
  return NK.functions.corsRequest(url, {"service":"WCS", "request":"GetCapabilities"});
};
NK.functions.corsRequest = function (url, params) {
  if(!!url) {
    if (url.slice(-1) != '?') {url = url+'?';}
    for (var k in params) {
      url += k+"="+params[k]+"&";
    }
    return $.ajax({
      url: '/ws/px.py',
      type: 'GET',
      data: url,
      dataType: 'xml'
    });
  }
};

NK.functions.addWMSLayer = function(wmsUrl) {
  if (NK.util.getLayersBy("url",wmsUrl).length) {return;}
  var layers = [], formats=[], crs=[], fiFormats=[], serviceParms={}, layerParms;

  var resultWMS = NK.functions.getWMSCapabilities(wmsUrl);
  resultWMS.error(function (msg) { NK.functions.log(msg.responseText); });
  resultWMS.done(function (xml) {
    serviceParms['version'] = $(xml).children()[0].getAttribute("version");
    $(xml).find('Service').each(function () {
      serviceParms['serviceTitle'] = $(this).children('Title').text();
    });
    $(xml).find('GetFeatureInfo').each(function () {
      $(this).children('Format').each(function() {
        fiFormats.push($(this).text());
      });
    });
    serviceParms['featureInfoFormats'] = fiFormats;
    $(xml).find('GetMap').each(function () {
      $(this).children('Format').each(function () {;
        formats.push($(this).text());
      });
    });
    serviceParms['formats'] = formats;
    var attribution;
    $(xml).find('Attribution').each(function () {
      var href = $(this).children('OnlineResource')[0];
      var logo = $(this).children('LogoURL').children('OnlineResource')[0];
      attribution = { 
          'title': $(this).children('Title').text(),
          'href' : href && href.getAttribute("xlink:href"),
          'logo' : logo && logo.getAttribute("xlink:href")
      }
    });
    if (!attribution) { attribution={'title':'missing', 'href':'#'}; }
    serviceParms['attribution'] = attribution;
    $(xml).find('AccessConstraints').each(function () {
      serviceParms['constraints'] = $(this).text();
    });
    $(xml).find('CRS').each(function () {
      crs.push($(this).text());
    });
    serviceParms['crs'] = crs;
    $(xml).find('Layer').each(function () {
      layerParms={};
      var name = $(this).children('Name').text();
      if (!name) {return;}

      /* if this layer is a child layer, identify parent */
      if ($(this).parent()[0].nodeName=="Layer") {
        layerParms['parent'] = $(this).parent().children('Title').text() || $(this).parent().children('Name').text();
      }

      layerParms['title'] = $(this).children('Title').text();
      layerParms['visible'] = !!NK.visibleLayerQueue[name];
      layerParms['opacity'] = NK.opacityQueue[name] || 1.0;
      if (name in NK.opacityQueue) {delete NK.opacityQueue[name];}
      if (name in NK.visibleLayerQueue) {delete NK.visibleLayerQueue[name];}
      layers.push(name);
      var bbox = $(xml).find('BoundingBox');
      if (!!bbox) {
        var atts = bbox[0].attributes;
        var srs = atts['CRS'] || atts['SRS'];
        if (srs && (srs.value == map.getView().getProjection().getCode())) { 
          layerParms['layerBounds'] = new OpenLayers.Bounds(atts["minx"].value, atts["miny"].value,
                                                            atts["maxx"].value, atts["maxy"].value);
        }
      }
      layerParms['layerText']=name;
      NK.functions.createDynamicWMSLayer(layerParms['title'], wmsUrl, $.extend({},serviceParms,layerParms));
      if (!!NK.xdm) {
        NK.functions.postMessage({"type":"layerLoaded", "title":layerParms['title'], "parent":layerParms['parent'],"url":wmsUrl}); 
      }
    });
    NK.functions.updateHistory();
  });

  if (NK.controls.Geoportal) {
    var geoportal =  NK.util.getControlsByClass(NK.controls.Geoportal)[0]; // heh, the optimism!
    geoportal.showControls(wmsUrl);
    geoportal.displayLayerList();
  }
};

/* monkeypatch for ol.source.TileWMS.getRequestUrl_ to support custom CRS ***/
ol.source.ImageWMS.prototype.getRequestUrl_orig = ol.source.ImageWMS.prototype.getRequestUrl_ ;
ol.source.ImageWMS.prototype.getRequestUrl_ = function(extent, size, pixelRatio, projection, params) {
  if (!!this.getProjection()) {
    projection = this.getProjection();
  }
  return this.getRequestUrl_orig(extent, size, pixelRatio, projection, params);
};


NK.functions.createDynamicWMSLayer = function (name, url, parms) {
  var crs = $.grep(parms['crs'], function(s) {
    return ($.inArray(s, NK.supportedCRS)>-1)
  })[0];

  var wms = new ol.layer.Image({
    title: parms['title'],
    source: new ol.source.ImageWMS({ 
      url: url,
      projection: crs,
      params: {
        LAYERS: parms['layerText'],
        VERSION: parms['version'], 
        //gkt: NK.gkToken || '',
        TRANSPARENT: true,
        EXCEPTIONS: 'XML',
        FORMAT: 'image/png'
      }
    }),
    serviceTitle: parms['serviceTitle'],
    parent: parms['parent'] || null,
    isBaseLayer: false,
    visible: parms['visible'],
    opacity: parms['opacity'] || 1.0,
    isUrlDataLayer: true,
    dataFormats: parms['formats'],
    attribution: parms['attribution'],
    constraints: parms['constraints'],
    type: 'wms'
  });
  if (!!parms['bounds']) {
    wms.set('maxExtent',parms['bounds']);
  }
  if (!!parms['featureInfoFormats']) {
    var formats = parms['featureInfoFormats'];
    var preferredFormats = ['application/vnd.ogc.wms_xml', 'text/xml', 'text/plain', 'text/html'];
    var preferredFormat  = 'x';

    while (preferredFormat && formats.indexOf(preferredFormat)==-1) {
      preferredFormat = preferredFormats.shift();
    }

    /* TODO *********
    if (!!preferredFormat) {
      var popupFn = NK.functions.popup.wmsFeatureInfoPopup;
      var featureInfo = new OpenLayers.Control.WMSGetFeatureInfo({
        url: url,
        proxyUrl: "/ws/px.py?"+url,
        title: parms['title'],
        queryVisible: true,
        infoFormat: preferredFormat,
        eventListeners: {
          "getfeatureinfo": function(event) {
            var popup = new OpenLayers.Popup.FramedSideAnchored(null, map.getLonLatFromPixel(event.xy), null, popupFn(event, formats), null, true,
                              NK.functions.closePopupCallBack, {x: 10, y: -65}, 'selected-feature-popup, user-marker')
            map.addPopup(popup, true);
            if (!event.features.length && (!event.text || !event.text.trim().length)) {
              setTimeout(function() {
                map.removePopup(popup);
              }, 3000);
            }
          }
        }
      });
      wms.featureInfoControl = featureInfo;
      wms.events.register('visibilitychanged', wms, function() {
        if(this.getVisibility()) {
          featureInfo.activate();
          if (!!this.maxExtent) {
            var extent = this.maxExtent;
            if (!extent.containsLonLat(map.getCenter())) {
              map.zoomToExtent(extent);
            }
          }
        } else {
          featureInfo.deactivate();
        }
      });
      map.addControl(featureInfo);
      if (parms['visible']) {
        featureInfo.activate();
      }
    }
    *********************/
  }
  map.addLayer(wms);
  // NK.functions.createLegend();
};

NK.functions.addWFSLayer = function(wfsUrl) {
  if (NK.util.getLayersBy("url",wfsUrl).length) {return;}
  var layers = [], crs=[], formats={}, serviceParms={}, layerParms;
  var resultWFS = NK.functions.getWFSCapabilities(wfsUrl);
  resultWFS.error(function (msg) { NK.functions.log(msg.responseText); });
  resultWFS.done(function (xml) {
    var version = $(xml).find('ServiceTypeVersion')
    if (!!version) {version = version.text().trim();}
    serviceParms['version'] = version;
    var exception = $(xml).find('ExceptionText').text();
    if (!!exception) {
      NK.functions.log(exception);
    } else {
      $(xml).find('Service').each(function () {
        serviceParms['serviceTitle'] = $(this).children('Title').text();
      });
      $(xml).find('OutputFormats').each(function () {
        $(this).children('Format').each(function () {;
          formats[$(this).text()] = true;
        });
      });
      serviceParms['formats'] = Object.keys(formats);
      $(xml).find('AccessConstraints').each(function () {
        serviceParms['constraints'] = $(this).text();
      });
      var attribution;
      $(xml).find('Attribution').each(function () {
        var href = $(this).children('OnlineResource')[0];
        var logo = $(this).children('LogoURL').children('OnlineResource')[0];
        attribution = { 
          'title': $(this).children('Title').text(),
          'href' : href && href.getAttribute("xlink:href"),
          'logo' : logo && logo.getAttribute("xlink:href")
        }
      });
      if (!attribution) { attribution={'title':'missing', 'href':'#'}; }
      serviceParms['attribution'] = attribution;
      $(xml).find('DefaultSRS').each(function () {
        crs.push($(this).text());
      });
      $(xml).find('OtherSRS').each(function () {
        crs.push($(this).text());
      });
      serviceParms['crs'] = crs;
      $(xml).find('FeatureType').each(function () {
        layerParms = {};
        var name = $(this).children('Name').text();
        if (!name) {return;}
        layers.push(name);
        layerParms['title'] = $(this).children('Title').text();
        layerParms['visible'] = name in NK.visibleLayerQueue;
        if (name in NK.visibleLayerQueue) {delete NK.visibleLayerQueue[name];}
        if (name in NK.opacityQueue) {delete NK.opacityQueue[name];}
        layerParms['opacity'] = NK.opacityQueue[name] || 1.0;
        layerParms['type'] = name;
        NK.functions.createDynamicWFSLayer(layerParms['title'], wfsUrl, $.extend({},serviceParms, layerParms));
        if (!!NK.xdm) {
          NK.functions.postMessage({"type":"layerLoaded", "title":layerParms['title'], "url":wfsUrl}); 
        }
      });
      NK.functions.updateHistory();
    }
  });

  if (NK.controls.Geoportal) {
    //var geoportal =  map.getControlsByClass('OpenLayers.Control.Geoportal')[0];
    geoportal.showControls(wfsUrl);
    geoportal.displayLayerList();
  }
};

/** monkey patch to accept any name space in ol.xml.parse ***/
ol.xml.parse_orig = ol.xml.parse;
ol.xml.parse = function(parsersNS, node, objectStack, opt_this) {
  if (!!parsersNS["*"]) {
    parsersNS[node.firstElementChild.namespaceURI] = parsersNS["*"];
  } 
  return ol.xml.parse_orig(parsersNS, node, objectStack, opt_this);
} 
/************************************************************/

NK.functions.createDynamicWFSLayer = function (name, url, parms) {
  // TODO: read GeoJSON if supported  
  // var format = new ol.format.GeoJSON();

  var crs = $.grep(parms['crs'], function(s) {
    return ($.inArray(s, NK.supportedCRS)>-1)
  })[0];
  var format = new ol.format.WFS({
    featureNS:   '*', //see monkey patch above,
    //featureNS:   'http://mapserver.gis.umn.edu/mapserver', //FIXME: parms['namespace'],
    featureType: parms['type']
  });
  var source = new ol.source.ServerVector({
    format: format,
    loader: function(extent, resolution, projection) {
      var request = "/ws/px.py?" + url + "?service=WFS&version=1.1.0&request=GetFeature";
      request += "&typename=" + parms['type'];
      request += "&srsName=" + crs; //TODO
      request += "&bbox="+extent.join(",");
      $.ajax({url:request}).done(function(response) {
        var features = source.readFeatures(response);
        source.addFeatures(features);
      });
    }
  });
  var wfs = new ol.layer.Vector({
    source: source,
    style: NK.styles.wfs['default'],
    type: 'wfs',
    url:  url,
    featureType: parms['type'],
    dataFormats: parms['formats'],
    attribution: parms['attribution'],
    constraints: parms['constraints'],
    visible:     parms['visible'],
    opacity:     parms['opacity'], 
    isUrlDataLayer: true
  });

  map.addLayer(wfs);
  NK.functions.vector.addHoverControls(map, wfs, NK.styles.wfs.highlight); 
} 
