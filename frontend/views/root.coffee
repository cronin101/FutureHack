$ ->
  GLASGOW_COORDS = [55.858, -4.2590]
  Here = nokia.maps
  App = {
    actions: {
      clear_map: ->
        undefined

      reset_zoom: ->
        App.map.set 'zoomLevel', 12
        App.map.set 'center', GLASGOW_COORDS

      zoom_to_bounding_box: (box, keep_center = true) ->
        zoom = ->
          App.map.zoomTo box, keep_center, 'default'
        setTimeout zoom, 1000

      clear_and_rezoom: (cb) ->
        @clear_map(cb)
        @reset_zoom()
        @zoom_to_bounding_box App.user_bounding_box

      place_user_marker: ->
        App.user_marker = (new
            Here.map.StandardMarker App.user_location, text: 'Me')
        App.map.objects.add App.user_marker

      remove_user_marker: ->
        if App.user_marker
          App.user_marker.destroy()

      set_user_location: (lat, lon) ->
        @remove_user_marker()
        App.user_location = [lat, lon]
        @place_user_marker()

        App.user_bounding_box = new Here.geo.BoundingBox App.user_location
        @zoom_to_bounding_box App.user_bounding_box

      find_nearest_geojson_point: (json, target = App.user_location) ->
        parsed_geojson = L.geoJson json
        user_leaf_geoloc = L.latLng.apply this, target
        nearest_point = leafletKnn(parsed_geojson)
            .nearest(user_leaf_geoloc, 1)[0]

      show_path_from_user_via_rack: (rack, loo) ->
        @remove_user_marker()
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
            @clear_map = (cb) ->
              container.destroy()
              @place_user_marker()
              cb()
            container.objects.add(new Here.map.Polyline(route.shape, {
              arrows: {
                "frequency": 4
                "length": 2.3
                "width": 1.0
                "color": "#FFFC"
              }
              pen: new Here.util.Pen({
                lineWidth: 5,
                strokeColor: "#2090ED"
              })
            }))
            App.map.objects.add container
            for waypoint, i in route.waypoints
              text = switch i
                when 0 then 'Me'
                when 1 then 'R'
                when 2 then 'T'

              color = switch i
                when 1 then '#FF4444'
                when 2 then '#44FF44'
                else '#1080DD'

              container.objects.add (new
                  Here.map.StandardMarker waypoint.originalPosition,
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
        @remove_user_marker()
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
            mapRoute = new
                Here.routing.component.RouteResultSet(routes[0]).container
            @clear_map = (cb) ->
              mapRoute.destroy()
              @place_user_marker()
              cb()
            App.map.objects.add mapRoute

            # Zoom to the bounding box of the route, discard current map center
            @zoom_to_bounding_box mapRoute.getBoundingBox(), false

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
        center:      GLASGOW_COORDS 
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
      @actions.clear_map ->
        @rack_directions_shown = false


    direct_to_nearest_object: (endpoint = '/toilets.geojson') ->
      $.getJSON endpoint, (data) =>
        nearest_obj = @actions.find_nearest_geojson_point data
        obj_coords = [nearest_obj.lat, nearest_obj.lon]
        $.getJSON 'cycle-racks.geojson', (rdata) =>
          nearest_rack = @actions.find_nearest_geojson_point rdata, obj_coords
          @actions.show_path_from_user_via_rack nearest_rack, nearest_obj


    show_cycle_racks: ->
      $.getJSON '/cycle-racks.geojson', (data) =>
        @rack_cluster = @actions.display_new_geojson_cluster data
      @cycle_racks_shown = true


    hide_cycle_racks: ->
      @rack_cluster.clean()
      @cycle_racks_shown = false
  }


  App.set_credentials()
  App.$cycle_racks = $ '#cycle_racks'
  App.$find_nearest = $ '#find_nearest'
  App.$poi_button = $ '#poi_button'
  App.$clear_poi = $ '#clear_poi'

  Controller = {
    toggle_cycle_racks: ->
      if not App.cycle_racks_shown
        App.show_cycle_racks()
        App.$cycle_racks.text "Hide cycle-racks"
      else
        App.hide_cycle_racks()
        App.$cycle_racks.text "Show all cycle-racks"

    toggle_nearest_rack_direction: ->
      if not App.rack_directions_shown
        App.direct_to_nearest_rack()
        App.$find_nearest.text "Hide directions"
      else
        App.rack_directions_shown = false
        App.actions.clear_and_rezoom ->
          App.$find_nearest.text "Direct me to the nearest cycle-rack"

    lock_buttons_after_poi: (poi_text) ->
      App.$poi_button.text poi_text
      App.$find_nearest.click() if App.rack_directions_shown
      for button in [App.$poi_button, App.$find_nearest]
        button.attr 'disabled', 'disabled'
      App.$clear_poi.show()

    show_nearest_loo: ->
      Controller.lock_buttons_after_poi 'Public Toilet'
      App.direct_to_nearest_object '/toilets.geojson'

    reset_after_poi: ->
      App.actions.clear_and_rezoom ->
        App.$poi_button.html 'place of interest <span class="caret"></span>'
        for button in [App.$poi_button, App.$find_nearest]
          button.removeAttr 'disabled'
        App.$clear_poi.hide()
  }

  navigator.geolocation.getCurrentPosition (user_location) ->
    App.create_map user_location

  App.$cycle_racks.click Controller.toggle_cycle_racks
  App.$find_nearest.click Controller.toggle_nearest_rack_direction
  ($ '#find_me_a_loo').click Controller.show_nearest_loo
  App.$clear_poi.click Controller.reset_after_poi

  window.App = App

