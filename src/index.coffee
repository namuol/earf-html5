html ->
  head ->
    link rel:'stylesheet', href:'style.css'
  body ->
    div id:'main', ->
      div id:'inner', ->
        canvas id:'scr', width:'160', height:'100', 'THIS IS A CANVAS.'

  coffeescript ->
    scr_el = document.getElementById('scr')
    c = scr_el.getContext '2d'
    SCR_W = scr_el.width
    SCR_H = scr_el.height
    MAX_D = 255
    LOD_FACTOR = 8

    map_el = new Image()
    map_el.onload = ->
      map_canvas = document.createElement 'canvas'
      map_canvas.setAttribute 'width', map_el.width
      map_canvas.setAttribute 'height', map_el.height
      map_ctx = map_canvas.getContext '2d'
      map_ctx.drawImage map_el, 0,0
      map = map_ctx.getImageData 0,0, map_el.width, map_el.height

      # shim layer with setTimeout fallback
      window.requestAnimFrame = do ->
        return  window.requestAnimationFrame       ||
                window.webkitRequestAnimationFrame ||
                window.mozRequestAnimationFrame    ||
                window.oRequestAnimationFrame      ||
                window.msRequestAnimationFrame     ||
                (callback) ->
                  window.setTimeout callback, 1000 / 20

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

      window.cam = new Camera(new Vector(127,64,127), 45, SCR_W,SCR_H)

      setPixel = (imageData, x, y, r, g, b, a) ->
        index = (x + y * imageData.width) * 4
        imageData.data[index] = r
        imageData.data[index + 1] = g
        imageData.data[index + 2] = b
        imageData.data[index + 3] = a

      render = ->
        cam.eye.x += 0.5
        cam.eye.z += 0.5
        scr = c.createImageData(SCR_W, SCR_H)
        x = 0
        ch = cam.eye.y
        while x < SCR_W
          maxY = SCR_H-1
          ray = cam.getRayFromUV(x, 0)

          d = 35
          while d < MAX_D
            cx = Math.floor(cam.eye.x + ray.x * d) % map.width
            cz = Math.floor(cam.eye.z + ray.z * d) % map.height
            pos = (cx + cz * map.width) * 4
            r = map.data[pos]

            h = r * 0.25
            y = Math.floor(SCR_H - (((h - ch) * 150) / d + SCR_H))
            if not (y < 0)
              if y < maxY
                _y = maxY
                while _y > y and _y < SCR_H
                  fog = 1.0 - d/MAX_D
                  g = map.data[pos + 1]
                  b = map.data[pos + 2]
                  setPixel(scr, x,_y, r,g,b, 0xff*fog)
                  --_y
                maxY = y
            d += 2# + LOD_FACTOR*Math.floor((d-30)/MAX_D)
          ++x
        c.putImageData scr, 0, 0

      animloop = ->
        requestAnimFrame(animloop)
        render()

      animloop()

    map_el.src = 'heightmap.jpg'
