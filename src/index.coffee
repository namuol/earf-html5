html ->
  head ->
    link rel:'stylesheet', href:'style.css'
  body ->
    div class:'ribbon', ->
      a href:'http://github.com/namuol/earf-html5', 'fork me on github'

    div id:'main', ->
      p ->
        text 'A simple heightmap raycaster. 100% javascript and HTML5 canvas.'
      div id:'inner', ->
        canvas id:'scr', width:'160', height:'100', 'THIS IS A CANVAS.'
        text 'Use the arrow keys to move around.'

  coffeescript ->
    LEFT = 37
    RIGHT = 39
    UP = 38
    DOWN = 40
    left=right=up=down=false

    scr_el = document.getElementById('scr')
    c = scr_el.getContext '2d'
    SCR_W = scr_el.width
    SCR_H = scr_el.height
    MAX_D = 255
    LOD_FACTOR = 8
    DETAIL = 2

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

      window.cam = new Camera(new Vector(127,64,127), 45, SCR_W,SCR_H)
      cam.setAng(-Math.PI)

      setPixel = (imageData, x, y, r, g, b, a) ->
        index = (x + y * imageData.width) * 4
        imageData.data[index] = r
        imageData.data[index + 1] = g
        imageData.data[index + 2] = b
        imageData.data[index + 3] = a
      handle_key = (e, isdown) ->
        if e.keyCode is LEFT
          left = isdown
        else if e.keyCode is RIGHT
          right = isdown
        else if e.keyCode is UP
          up = isdown
        else if e.keyCode is DOWN
          down = isdown

      window.onkeydown = (e) ->
        handle_key e, true
      window.onkeyup = (e) ->
        handle_key e, false
        
      cv = new Vector(0,0,0)
      render = ->
        do ->
          cx = Math.floor(cam.eye.x) % map.width
          cz = Math.floor(cam.eye.z) % map.height
          if cx > 0 and cz > 0
            pos = (cx + cz * map.width) * 4
            h = map.data[pos] * 0.25
            target = (h+45) - cam.eye.y
            cv.y = (target - cv.y) * 0.03
          if (up)
            cv = cv.add(cam.look.mul(0.2))
          if (down)
            cv = cv.sub(cam.look.mul(0.2))
          if (left)
            cam.setAng(cam.ang + 0.035)
          if (right)
            cam.setAng(cam.ang - 0.035)

          cam.eye.x += cv.x
          cam.eye.y += cv.y
          cam.eye.z += cv.z
          cv = cv.mul 0.9

        scr = c.createImageData(SCR_W, SCR_H)
        x = 0
        ch = cam.eye.y
        while x < SCR_W
          maxY = SCR_H-1
          ray = cam.getRayFromUV(x, 0)

          d = 15
          while d < MAX_D/2
            cx = Math.floor(cam.eye.x + ray.x * d) % map.width
            cz = Math.floor(cam.eye.z + ray.z * d) % map.height
            pos = (cx + cz * map.width) * 4
            r = map.data[pos]

            h = r * 0.25
            y = Math.floor(SCR_H - (((h - ch) * 150) / d + SCR_H))
            if not (y < 0)
              if y < maxY
                _y = maxY
                fog = 1.0 - (d-100)/(MAX_D-100)
                g = map.data[pos + 1]
                b = map.data[pos + 2]
                while _y > y and _y < SCR_H
                  setPixel(scr, x,_y, r,g,b, 0xff*fog)
                  --_y
                maxY = y
            d += DETAIL# + LOD_FACTOR*Math.floor((d-30)/MAX_D)
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
                fog = 1.0 - (d-100)/(MAX_D-100)
                g = map.data[pos + 1]
                b = map.data[pos + 2]
                while _y > y and _y < SCR_H
                  setPixel(scr, x,_y, r,g,b, 0xff*fog)
                  --_y
                maxY = y
            d += DETAIL*2# + LOD_FACTOR*Math.floor((d-30)/MAX_D)

          ++x
        c.putImageData scr, 0, 0

      animloop = ->
        requestAnimFrame(animloop)
        render()

      animloop()

    map_el.src = 'heightmap.jpg'
