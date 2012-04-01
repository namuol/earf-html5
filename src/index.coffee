html ->
  head ->
    link rel:'stylesheet', href:'style.css'
  body ->
    img id:'map', src:'heightmap.jpg', style:'display:none'
    div id:'main', ->
      div id:'inner', ->
        canvas id:'scr', width:'320', height:'240', 'THIS IS A CANVAS.'

  coffeescript ->
    scr_el = document.getElementById('scr')
    c = scr_el.getContext '2d'
    SCR_W = scr_el.width
    SCR_H = scr_el.height
    MAX_D = 255

    map_el = document.getElementById 'map'
    map_el.onload = ->
      console.log 'loaded'
      map_canvas = document.createElement 'canvas'
      map_canvas.setAttribute 'width', map_el.width
      map_canvas.setAttribute 'height', map_el.height
      map_ctx = map_canvas.getContext '2d'
      map_ctx.drawImage map_el, 0,0
      map = map_ctx.getImageData()
      document.getElementById('inner').appendChild(map_canvas)

      # shim layer with setTimeout fallback
      window.requestAnimFrame = do ->
        return  window.requestAnimationFrame       ||
                window.webkitRequestAnimationFrame ||
                window.mozRequestAnimationFrame    ||
                window.oRequestAnimationFrame      ||
                window.msRequestAnimationFrame     ||
                (callback) ->
                  window.setTimeout callback, 1000 / 60

      class Vector
        constructor: (@x, @y, @z) ->
        add: (v) ->
          return new Vector(@x+v.x, @y+v.y, @z+v.z)
        sub: (v) ->
          return new Vector(@x-v.x, @y-v.y, @z-v.z)
        mul: (s) ->
          return new Vector(@x*s,@y*s,@z*s)

        normal: ->
          mag = Math.sqrt(@x*@x + @y*@y + @z*@z)
          @x /= mag
          @y /= mag
          @z /= mag
          @

      class Camera
        constructor: (@eye, @fovy, @scr_w, @scr_h) ->
          @fovx = (@scr_w/@scr_h) * @fovy

          # Precompute ray position variables for quick ray generation in "getRayFromUV":
          @xstart = -0.5*@fovx/45.0
          @ystart = 0.5*@fovy/45.0
          @xmult = (@fovx/45.0) / @scr_w
          @ymult = -(@fovy/45.0) / @scr_h
          @setAng(0)

        setAng: (v) ->
          @ang = v
          @look = new Vector(-Math.sin(@ang), 0, -Math.cos(@ang)).normal()
          @perp = new Vector(-Math.sin(@ang + Math.PI/2), 0, -Math.cos(@ang + Math.PI/2)).normal()

        getRayFromUV: (u, v)->
          p = @look.sub((@perp.mul((@xstart + u*@xmult))))
          return new Vector(p.x, @ystart + v*@ymult, p.z).normal()

      window.cam = new Camera(new Vector(127,64,127), 45, 100, 100)

      setPixel = (imageData, x, y, r, g, b, a) ->
        index = (x + y * imageData.width) * 4
        imageData.data[index + 0] = r
        imageData.data[index + 1] = g
        imageData.data[index + 2] = b
        imageData.data[index + 3] = a

      render = ->
        scr = c.createImageData(SCR_W, SCR_H)
        maxY = 0
        x = 0
        while x < SCR_W
          ray = cam.getRayFromUV(x, 0)

          d = 35
          while d < MAX_D
            cx = cam.eye.x + ray.x * d
            cz = cam.eye.z + ray.z * d
            ++d

          ++x
        c.putImageData map, 0, 0

      animloop = ->
        requestAnimFrame animloop
        render()

      animloop()
