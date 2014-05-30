$ ->
  Here = nokia.maps
  App = {
    actions: {
      zoom_to_bounding_box: (box, keep_center = true) ->
        zoom = ->
          App.map.zoomTo box, keep_center, 'default'
        setTimeout zoom, 1000

      set_user_location: (lat, lon) ->
        if App.user_marker
          App.user_marker.destroy()
        App.user_location = [lat, lon]

        App.user_marker = new Here.map.StandardMarker App.user_location
        App.map.objects.add App.user_marker

        App.user_bounding_box = new Here.geo.BoundingBox App.user_location
        @zoom_to_bounding_box App.user_bounding_box

      find_nearest_geojson_point: (json, target = App.user_location) ->
        parsed_geojson = L.geoJson json
        user_leaf_geoloc = L.latLng.apply this, target
        nearest_point = leafletKnn(parsed_geojson)
            .nearest(user_leaf_geoloc, 1)[0]

      show_path_from_user_via_rack: (rack, loo) ->
        user_nok_geoloc = new
            Here.geo.Coordinate App.user_location[0], App.user_location[1]
        rack_nok_geoloc = new
            Here.geo.Coordinate rack.lat, rack.lon
        loo_nok_geoloc = new
            Here.geo.Coordinate loo.lat, loo.lon

        points = new Here.routing.WaypointParameterList()
        for point in [user_nok_geoloc, rack_nok_geoloc, loo_nok_geoloc]
          points.addCoordinate point

        router = new Here.routing.Manager()
        router.addObserver "state", (observedRouter, key, value) =>
          if value == "finished"
            routes = observedRouter.getRoutes()
            route = routes[0]
            App.route_length = routes[0].summary.distance
            container = new Here.map.Container()
            container.objects.add( new Here.map.Polyline(route.shape, {
              pen: new Here.util.Pen({
                lineWidth: 5,
                strokeColor: "#1080DD"
              })
            }))
            App.map.objects.add container
            for waypoint, i in route.waypoints
              text = switch i
                when 0 then 'Me'
                when 1 then 'R'
                when 2 then 'T'

              color = switch i
                when 1 then '#44AA44'
                else '#1080DD'

              container.objects.add (new Here.map.StandardMarker waypoint.originalPosition,
                text: text
                brush: (color: color)
              )

            # Zoom to the bounding box of the route, discard current map center
            @zoom_to_bounding_box container.getBoundingBox(), false

        router.calculateRoute points, [
          type: "shortest"
          transportModes: ["car"]
          options: ["avoidTollroad", "avoidMotorway"]
          trafficMode: "default"
        ]


      show_path_from_user_to: (dest_lat, dest_lon) ->
        user_nok_geoloc = new
            Here.geo.Coordinate App.user_location[0], App.user_location[1]
        destination_nok_geoloc = new
            Here.geo.Coordinate dest_lat, dest_lon

        points = new Here.routing.WaypointParameterList()
        points.addCoordinate user_nok_geoloc
        points.addCoordinate destination_nok_geoloc

        router = new Here.routing.Manager()
        router.addObserver "state", (observedRouter, key, value) =>
          if value == "finished"
            routes = observedRouter.getRoutes()
            App.route_length = routes[0].summary.distance
            # Create the default map representation of a route
            App.mapRoute = new
                Here.routing.component.RouteResultSet(routes[0]).container
            App.map.objects.add App.mapRoute

            # Zoom to the bounding box of the route, discard current map center
            @zoom_to_bounding_box App.mapRoute.getBoundingBox(), false

        router.calculateRoute points, [
          type: "shortest"
          transportModes: ["car"]
          options: ["avoidTollroad", "avoidMotorway"]
          trafficMode: "default"
        ]

      display_new_geojson_cluster: (data) ->
        cluster = new Here.clustering.ClusterProvider App.map,
          eps:        10
          minPts:     1
          dataPoints: []

        for point in data.features
          coords = point.geometry.coordinates.reverse()
          cluster.add latitude: coords[0], longitude: coords[1]

        cluster.cluster()
        cluster
    }


    set_credentials: ->
      nokia.Settings.set 'app_id', 'dAeplRpqXA3pPri5MWDE'
      nokia.Settings.set 'app_code', '0taRg556WF-uaMDhXddFtw'


    create_map: (user_position) ->
      @map = new Here.map.Display (document.getElementById "mapContainer"),
        center:      [55.858, -4.2590] # Centred on Lat/Long for Glasgow
        zoomLevel:   12
        components:  [new Here.map.component.Behavior()] # Map Pan/Zoom

      coords = user_position.coords
      @actions.set_user_location coords.latitude, coords.longitude


    direct_to_nearest_rack: ->
      $.getJSON '/cycle-racks.geojson', (data) =>
        nearest = @actions.find_nearest_geojson_point data
        @actions.show_path_from_user_to nearest.lat, nearest.lon
      @rack_directions_shown = true


    hide_rack_directions: ->
      @mapRoute.destroy()
      @rack_directions_shown = false


    direct_to_nearest_loo: ->
      $.getJSON '/toilets.geojson', (data) =>
        nearest_loo = @actions.find_nearest_geojson_point data
        loo_coords = [nearest_loo.lat, nearest_loo.lon]
        $.getJSON 'cycle-racks.geojson', (rdata) =>
          nearest_rack = @actions.find_nearest_geojson_point rdata, loo_coords
          @actions.show_path_from_user_via_rack nearest_rack, nearest_loo


    show_cycle_racks: ->
      $.getJSON '/cycle-racks.geojson', (data) =>
        @rack_cluster = @actions.display_new_geojson_cluster data
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
      ($ this).text "Hide cycle-racks"
    else
      App.hide_cycle_racks()
      ($ this).text "Show all cycle-racks"

  ($ '#cycle_racks').click cycle_rack_toggle

  nearest_rack_direction_toggle = ->
    if not App.rack_directions_shown
      App.direct_to_nearest_rack()
      ($ this).text "Hide directions"
    else
      App.hide_rack_directions()
      ($ this).text "Direct me to the nearest cycle-rack"

  ($ '#find_nearest').click nearest_rack_direction_toggle

  ($ '#find_me_a_loo').click ->
    App.direct_to_nearest_loo()

  window.App = App

