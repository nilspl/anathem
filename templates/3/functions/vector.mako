% if not 'vectorControls' in vars:  

NK.functions = NK.functions || {};
NK.functions.vector = NK.functions.vector || {};

NK.functions.vector.markAllById = function (layer, intent, preserveIntent) {
  return function(element, evt) {
    if (preserveIntent && element.feature.renderIntent === preserveIntent) {
      return false;
    }
    // highlight all elements with the same element.feature.fid
    var ident = layer.getFeaturesByFid(element.feature.fid);
    $.each(ident, function (i, feature) {

      if (preserveIntent && feature.renderIntent === preserveIntent) {
        return false;
      } else {
        feature.renderIntent = intent;
        layer.drawFeature(feature);
      }
    });
  };
};

NK.functions.vector.addVectorHoverControls = function (map, layer, options) {
  var hoverCtrl,
      selectFeatureProperties;

  selectFeatureProperties = {
      hover: true,
      highlightOnly: true,
      renderIntent: "temporary"
  };

  if (options && options.groupByFid) {
    selectFeatureProperties.eventListeners = {
        beforefeaturehighlighted: NK.functions.vector.markAllById(layer, "temporary", options.preserveIntent),
        featureunhighlighted: NK.functions.vector.markAllById(layer, "default", options.preserveIntent)
    };
  }

  /* TODO ****
  hoverCtrl = new OpenLayers.Control.SelectFeature(
    layer,
    selectFeatureProperties
  );


  map.addControl(hoverCtrl);
  hoverCtrl.activate();
  return hoverCtrl;
  ***/ 
};

NK.functions.vector.addVectorControls = function (map, layer, options) {
  var controls = {};

  controls.hover = NK.functions.vector.addVectorHoverControls(map, layer, options);

  return controls;
};


<% vars['vectorControls']=True %>
% endif
