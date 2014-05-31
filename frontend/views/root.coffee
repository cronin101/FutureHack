$ ->
  GLASGOW_COORDS = [55.858, -4.2590]
  Here = nokia.maps
  InfoBubbles = new nokia.maps.map.component.InfoBubbles()

  TransportModes = {
    WALK: 0
    BIKE: 1
  }
  App = {
    transport_mode: (TransportModes.BIKE)

    actions: {
      get_transport_options: ->
        switch App.transport_mode
          when TransportModes.WALK
            [
              type: "shortest"
              transportModes: ["pedestrian"]
            ]
          when TransportModes.BIKE
            [
              type: "shortest"
              transportModes: ["car"]
              options: ["avoidTollroad", "avoidMotorway"]
              trafficMode: "default"
            ]

      clear_map: (cb) ->
        cb()

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

      show_path_from_user_via_rack: (rack, loo, des_initial) ->
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
            route_length = routes[0].summary.distance
            message = route_length + 'm to go!'
            bubble = InfoBubbles.openBubble message,  user_nok_geoloc
            container = new Here.map.Container()
            @clear_map = (cb) ->
              container.destroy()
              bubble.close()
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
                when 2 then des_initial

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

        router.calculateRoute points, App.actions.get_transport_options()

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
            route_length = routes[0].summary.distance
            message = route_length + 'm to go!'
            bubble = InfoBubbles.openBubble message,  user_nok_geoloc
            # Create the default map representation of a route
            mapRoute = new
                Here.routing.component.RouteResultSet(routes[0]).container
            @clear_map = (cb) ->
              mapRoute.destroy()
              bubble.close()
              @place_user_marker()
              cb()
            App.map.objects.add mapRoute

            # Zoom to the bounding box of the route, discard current map center
            @zoom_to_bounding_box mapRoute.getBoundingBox(), false

        router.calculateRoute points, App.actions.get_transport_options()

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
        components:  [
          new Here.map.component.Behavior() # Map Pan/Zoom
          InfoBubbles
        ]

      coords = user_position.coords
      @actions.set_user_location coords.latitude, coords.longitude


    direct_to_nearest_object: (endpoint = '/cycle-racks.geojson') ->
      $.getJSON endpoint, (data) =>
        nearest = @actions.find_nearest_geojson_point data
        @actions.show_path_from_user_to nearest.lat, nearest.lon
      @rack_directions_shown = true if App.transport_mode == TransportModes.BIKE


    hide_rack_directions: ->
      @actions.clear_map ->
        @rack_directions_shown = false


    direct_to_nearest_object_via_rack: (endpoint = '/toilets.geojson', des_initial) ->
      $.getJSON endpoint, (data) =>
        near_obj = @actions.find_nearest_geojson_point data
        obj_coords = [near_obj.lat, near_obj.lon]
        $.getJSON 'cycle-racks.geojson', (rdata) =>
          near_rack = @actions.find_nearest_geojson_point rdata, obj_coords
          @actions.show_path_from_user_via_rack near_rack, near_obj, des_initial


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
  App.$cycle_toggle = $ '#cycle_toggle'
  App.$walk_toggle = $ '#walk_toggle'
  App.$rack_buttons = $ '#rack_buttons'
  App.$via_cycle_text = $ '#via_cycle_text'

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
        App.direct_to_nearest_object './cycle-racks.geojson'
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

    set_destination: (e, i)->
      switch App.transport_mode
        when TransportModes.BIKE then App.direct_to_nearest_object_via_rack e, i
        when TransportModes.WALK then App.direct_to_nearest_object e

    show_nearest_loo: ->
      Controller.lock_buttons_after_poi 'Public Toilet'
      Controller.set_destination '/toilets.geojson', 'T'

    show_nearest_bikeshop: ->
      Controller.lock_buttons_after_poi 'Bike Shop'
      Controller.set_destination '/bikeshops.geojson', 'B'

    show_nearest_rail_station: ->
      Controller.lock_buttons_after_poi 'Rail Station'
      Controller.set_destination '/glasgow-rail-references.geojson', 'S'

    show_nearest_takeaway: ->
      Controller.lock_buttons_after_poi 'Takeaway'
      Controller.set_destination '/takeaway-and-sandwich-shop.geojson', 'T'

    reset_after_poi: ->
      App.actions.clear_and_rezoom ->
        App.$poi_button.html 'place of interest <span class="caret"></span>'
        for button in [App.$poi_button, App.$find_nearest]
          button.removeAttr 'disabled'
        App.$clear_poi.hide()

    select_walking: ->
      App.actions.clear_and_rezoom ->
        App.$cycle_toggle.removeClass('btn-success')
            .addClass('btn-primary').removeAttr 'disabled'
        App.$walk_toggle.removeClass('btn-primary')
            .addClass('btn-success').attr('disabled', 'disabled')
        App.transport_mode = TransportModes.WALK
        App.$rack_buttons.hide()
        App.$via_cycle_text.hide()

    select_cycling: ->
      App.actions.clear_and_rezoom ->
        App.$walk_toggle.removeClass('btn-success')
              .addClass('btn-primary').removeAttr 'disabled'
        App.$cycle_toggle.removeClass('btn-primary')
              .addClass('btn-success').attr('disabled', 'disabled')
        App.transport_mode = TransportModes.BIKE
        App.$rack_buttons.show()
        App.$via_cycle_text.show()
  }

  navigator.geolocation.getCurrentPosition (user_location) ->
    App.create_map user_location

  App.$cycle_racks.click Controller.toggle_cycle_racks
  App.$find_nearest.click Controller.toggle_nearest_rack_direction
  ($ '#find_me_a_loo').click Controller.show_nearest_loo
  ($ '#find_me_a_bikeshop').click Controller.show_nearest_bikeshop
  ($ '#find_me_a_station').click Controller.show_nearest_rail_station
  ($ '#find_me_a_takeaway').click Controller.show_nearest_takeaway
  App.$clear_poi.click Controller.reset_after_poi
  App.$walk_toggle.click Controller.select_walking
  App.$cycle_toggle.click Controller.select_cycling

  window.App = App

