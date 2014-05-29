$ ->
  App = {
    be_a_monkey: (lat, lon) ->
      @user_location = [lat, lon]
      @user_marker.destroy()
      @user_marker = new nokia.maps.map.StandardMarker @user_location, {text: ''}
      @map.objects.add(@user_marker)
      @user_bounding_box = new nokia.maps.geo.BoundingBox(@user_location)
      zoom_to = =>
        @map.zoomTo(@user_bounding_box, true, 'default')

      setTimeout zoom_to, 1000

    set_credentials: ->
      nokia.Settings.set 'app_id', 'dAeplRpqXA3pPri5MWDE'
      nokia.Settings.set 'app_code', '0taRg556WF-uaMDhXddFtw'

    create_map: (user_position) ->
      mapContainer = document.getElementById("mapContainer")

      coords = user_position.coords
      @user_location = [coords.latitude, coords.longitude]

      @map = new nokia.maps.map.Display mapContainer, {
        # Centred on Lat/Long for Glasgow
        center:      [55.858, -4.2590],
        zoomLevel:   12,
        components:  [
          new nokia.maps.map.component.Behavior(), # Map Pan/Zoom
        ]
      }

      @user_marker = new nokia.maps.map.StandardMarker @user_location, {text: ''}
      @map.objects.add(@user_marker)
      @user_bounding_box = new nokia.maps.geo.BoundingBox(@user_location)
      zoom_to = =>
        @map.zoomTo(@user_bounding_box, true, 'default')

      setTimeout zoom_to, 1000

    find_nearest: ->
      $.getJSON '/cycle-racks.geojson', (data) =>
        gj = L.geoJson(data)
        nearest = leafletKnn(gj).nearest(L.latLng(@user_location[0], @user_location[1]), 1)[0]

        router = new nokia.maps.routing.Manager()
        points = new nokia.maps.routing.WaypointParameterList()
        points.addCoordinate(new nokia.maps.geo.Coordinate(@user_location[0], @user_location[1]))
        points.addCoordinate(new nokia.maps.geo.Coordinate(nearest.lat, nearest.lon))

        router.addObserver "state", (observedRouter, key, value) =>
          if value == "finished"
            routes = observedRouter.getRoutes()
            # Create the default map representation of a route
            @mapRoute = new nokia.maps.routing.component.RouteResultSet(routes[0]).container
            @map.objects.add(@mapRoute)

            # Zoom to the bounding box of the route
            @map.zoomTo(@mapRoute.getBoundingBox(), false, "default")

        router.calculateRoute(points, [
          type: "shortest",
          transportModes: ["car"],
          options: ["avoidTollroad", "avoidMotorway"],
          trafficMode: "default"
        ])
      @directions_shown = true

    hide_directions: ->
      @mapRoute.destroy()
      @directions_shown = false

    show_cycle_racks: ->
      $.getJSON '/cycle-racks.geojson', (data) =>
        @rack_cluster = new nokia.maps.clustering.ClusterProvider @map, {
          eps:         10,
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

  nearest_rack_direction_toggle = ->
    if not App.directions_shown
      App.find_nearest()
      $(this).text("Hide directions")
    else
      App.hide_directions()
      $(this).text("Direct me to the nearest cycle-rack")

  $('#find_nearest').click nearest_rack_direction_toggle

  window.App = App

