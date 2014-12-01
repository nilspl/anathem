% if not 'easyXDM' in vars:

<script type="text/javascript" src="js/easyXDM.debug.js"></script>
<script type="text/javascript">
    easyXDM.DomHelper.requiresJSON("js/json2.js");
</script>

<% vars['easyXDM']=True %>
% endif

<script type="text/javascript">
	var NK = NK || {};
	NK.easyXDM = NK.easyXDM || {};

	NK.easyXDM.socket = new easyXDM.Socket({
		onMessage: function (data, origin) {
			var json, 
				lonLat, 
				vectorLayers,
				rasterLayers,
				features,
				feature,
				layers,
				layer,
				controls,
				selector,
				raster,
				i, 
				j,
				k,
				l;
				var getVisibleFeaturesInLayer = function (layer) {
					var features = [],
						feature,
						i,
						j;

					for (i = 0, j = layer.features.length; i < j; i += 1) {
						if (layer.features[i].getVisibility() && layer.features[i].onScreen()) {
							feature = {};
							feature.fid = layer.features[i].fid;
							feature['attributes'] = layer.features[i]['attributes'];

							features.push(feature);
						}
					}
					return features;
				};
				var getFeaturesInLayer = function (layer) {
					var features = [],
						feature,
						i,
						j;

					for (i = 0, j = layer.features.length; i < j; i += 1) {
						feature = {};
						feature.fid = layer.features[i].fid;
						feature['attributes'] = layer.features[i]['attributes'];

						features.push(feature);
					}
					return features;
				};

			if (origin === this.remote) {
				json = easyXDM.getJSONObject().parse(data);
				
				if (json) {
					if (json.cmd === 'setCenter') {
						map.setCenter(new OpenLayers.LonLat(json.x, json.y), json.zoom);

					} else if (json.cmd === 'setVisibleVectorLayer') {
						vectorLayers  = map.getLayersByClass("OpenLayers.Layer.Vector").slice();

						for (i = 0, j = vectorLayers.length; i < j; i += 1) {
							layer = vectorLayers[i];

							if (layer.shortid === json.shortid) {
								layer.setVisibility(true);

								if (layer.preferredBackground) {
									rasterLayers = map.getLayersByClass("OpenLayers.Layer.WMTS");

									for (k = 0, l = rasterLayers.length; k < l; k += 1) {
										raster = rasterLayers[k];

										if (raster.shortid === layer.preferredBackground) {
											raster.setVisibility(true);
										} else if (!raster.isBaseLayer) {
											raster.setVisibility(false);
										}
									}
								}
							} else {
								layer.setVisibility(false);
							}
						} 
					} else if (json.cmd === 'getFeatures') {
						if (json.layer) {
							layers = map.getLayersBy('shortid', json.layer);

							if (layers.length > 0) {
								layer = layers[0];
								features = getFeaturesInLayer(layer);

								NK.functions.postMessage({"type": "layerFeatures", "layer": layer.shortid, "features": features});
							} else {
								NK.functions.postMessage({"type": "error", "message": "no such layer"});
							}
						} else {
							vectorLayers  = map.getLayersByClass("OpenLayers.Layer.Vector").slice();
							layers = [];

							for (i = 0, j = vectorLayers.length; i < j; i += 1) {
								layer = vectorLayers[i];
								layers.push({
									"layer": layer.shortid,
									"features": getFeaturesInLayer(layer)
								});
							}
							NK.functions.postMessage({"type": "features", "layers": layers});							
						}
					} else if (json.cmd === 'getVisibleFeatures') {
						if (json.layer) {
							layers = map.getLayersBy('shortid', json.layer);

							if (layers.length > 0) {
								layer = layers[0];
								features = getVisibleFeaturesInLayer(layer);

								NK.functions.postMessage({"type": "layerVisibleFeatures", "layer": layer.shortid, "features": features});
							} else {
								NK.functions.postMessage({"type": "error", "message": "no such layer"});
							}
						} else {
							vectorLayers  = map.getLayersByClass("OpenLayers.Layer.Vector").slice();
							layers = [];
							console.log(vectorLayers.length);
							for (i = 0, j = vectorLayers.length; i < j; i += 1) {
								layer = vectorLayers[i];
								layers.push({
									"layer": layer.shortid,
									"features": getVisibleFeaturesInLayer(layer)
								});
							}
							NK.functions.postMessage({"type": "visibleFeatures", "layers": layers});
						}
					} else if (json.cmd === 'selectFeature') {
						layers = map.getLayersBy('shortid', json.layer);
						feature = null;
						selector = null;

						if (layers.length > 0) {
							layer = layers[0];
							feature = layer.getFeatureByFid(json.feature);

							if (feature) {
								controls = layer.map.getControlsByClass('OpenLayers.Control.SelectFeature');

								for (i = 0, j = controls.length; i < j && selector === null; i += 1) {
									if (controls[i].layer.shortid === layer.shortid) {
										if (controls[i].click) {
											// ensure the correct control is used
											selector = controls[i];
										}
									}
								}
							}
						}
						if (feature !== null && selector !== null) {
							if (json.panAndZoom && feature.geometry.bounds) {
								feature.layer.map.zoomToExtent(feature.geometry.bounds);
							}
							selector.clickFeature.call(selector, feature);
						} else {
							NK.functions.postMessage({"type": "error", "message": "no such layer or feature"});
						}
					}
				}
			}
		}
	});

NK.functions = NK.functions || {};
NK.functions.postMessage = function (msg) {
	if (!!NK.easyXDM.socket) {
		NK.easyXDM.socket.postMessage(JSON.stringify(msg));
	}
};
</script>

