create_map_centered_on_user = (position) ->
  mapContainer = document.getElementById("mapContainer")

  coords = position.coords
  user_location = [coords.latitude, coords.longitude]

  map = new nokia.maps.map.Display mapContainer, {
    center:      user_location,
    zoomLevel:   11,
    components:  [
      new nokia.maps.map.component.Behavior(), # Map Pan/Zoom
    ]
  }

  standardMarker = new nokia.maps.map.StandardMarker user_location, {text: "Me"}
  map.objects.add standardMarker

  map


$ ->
  nokia.Settings.set 'app_id', 'dAeplRpqXA3pPri5MWDE'
  nokia.Settings.set 'app_code', '0taRg556WF-uaMDhXddFtw'

  map = navigator.geolocation.getCurrentPosition create_map_centered_on_user
