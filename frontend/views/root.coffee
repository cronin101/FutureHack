$ ->
  nokia.Settings.set 'app_id', 'dAeplRpqXA3pPri5MWDE'
  nokia.Settings.set 'app_code', '0taRg556WF-uaMDhXddFtw'

  mapContainer = document.getElementById("mapContainer")

  map = new nokia.maps.map.Display mapContainer, {
    # Centred on Lat/Long for Glasgow
    center:      [55.858, -4.2590],
    zoomLevel:   11,
    components:  [
      # Map Pan/Zoom
      new nokia.maps.map.component.Behavior(),
    ]
  }

