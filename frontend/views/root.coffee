$ ->
  App = {
    set_credentials: ->
      nokia.Settings.set 'app_id', 'dAeplRpqXA3pPri5MWDE'
      nokia.Settings.set 'app_code', '0taRg556WF-uaMDhXddFtw'

    create_map: (user_position) ->
      mapContainer = document.getElementById("mapContainer")

      coords = user_position.coords
      user_location = [coords.latitude, coords.longitude]

      @map = new nokia.maps.map.Display mapContainer, {
        # Centred on Lat/Long for Glasgow
        center:      [55.858, -4.2590],
        zoomLevel:   12,
        components:  [
          new nokia.maps.map.component.Behavior(), # Map Pan/Zoom
        ]
      }

      @map.objects.add(new nokia.maps.map.StandardMarker user_location, {text: ''})
      @user_bounding_box = new nokia.maps.geo.BoundingBox(user_location)
      zoom_to = =>
        @map.zoomTo(@user_bounding_box, true, 'default')

      setTimeout zoom_to, 1000


    show_cycle_racks: ->
      $.getJSON '/cycle-racks.geojson', (data) =>
        @rack_cluster = new nokia.maps.clustering.ClusterProvider @map, {
          eps:         16,
          minPts:      1,
          dataPoints:  []
        }

        for point in data.features
          coords = point.geometry.coordinates.reverse()
          @rack_cluster.add {latitude: coords[0], longitude: coords[1]}

        @rack_cluster.cluster()
        @cycle_racks_shown = true

    hide_cycle_racks: ->
      @rack_cluster.clean()
      @cycle_racks_shown = false
  }

  App.set_credentials()

  navigator.geolocation.getCurrentPosition (user_location) ->
    App.create_map user_location

  cycle_rack_toggle = ->
    if not App.cycle_racks_shown
      App.show_cycle_racks()
      $(this).text("Hide cycle racks")
    else
      App.hide_cycle_racks()
      $(this).text("Show all cycle racks")

  $('#cycle_racks').click cycle_rack_toggle

  window.App = App

