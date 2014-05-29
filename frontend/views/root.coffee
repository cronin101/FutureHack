create_map = (user_position) ->
  mapContainer = document.getElementById("mapContainer")

  coords = user_position.coords
  user_location = [coords.latitude, coords.longitude]

  map = new nokia.maps.map.Display mapContainer, {
    # Centred on Lat/Long for Glasgow
    center:      [55.858, -4.2590],
    zoomLevel:   12,
    components:  [
      new nokia.maps.map.component.Behavior(), # Map Pan/Zoom
    ]
  }
  console.log 'first'
  console.log map

  standardMarker = new nokia.maps.map.StandardMarker user_location, {text: "Me"}
  map.objects.add standardMarker

  map


$ ->
  nokia.Settings.set 'app_id', 'dAeplRpqXA3pPri5MWDE'
  nokia.Settings.set 'app_code', '0taRg556WF-uaMDhXddFtw'

  navigator.geolocation.getCurrentPosition (user_location) ->
    map = create_map user_location
    show_cycle_racks = ->
      $.getJSON '/cycle-racks.geojson', (data) ->
        clusterProvider = new nokia.maps.clustering.ClusterProvider map, {
          eps:         16,
          minPts:      1,
          dataPoints:  []
        }

        for point in data.features
          coords = point.geometry.coordinates.reverse()
          clusterProvider.add {latitude: coords[0], longitude: coords[1]}
         # marker = new nokia.maps.map.StandardMarker coords
         # map.objects.add marker
        clusterProvider.cluster()

    $('#cycle_racks').click ->
      show_cycle_racks()
      $(this).hide()


