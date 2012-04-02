html ->
  head ->
    link rel:'stylesheet', href:'style.css'
  body ->
    div class:'ribbon', ->
      a href:'http://github.com/namuol/earf-html5', 'fork me on github!'

    div id:'main', ->
      p ->
        text 'A simple heightmap raycaster. 100% javascript (coffeescript) and HTML5 canvas.'
        br ''
        text 'Terrain generated with '
        a href:'http://www.bundysoft.com/L3DT/', 'L3DT'
        text '.'
      div id:'inner', ->
        canvas id:'scr', width:'160', height:'100', 'THIS IS A CANVAS.'
        text 'Use the arrow keys to move around.'
        br ''
        label for:'lod', 'LOD intensity'
        input type:'range', min:'2', max:'12', step:'1', id:'lod'
        br ''

        label for:'dd', 'draw distance'
        input type:'range', min:'255', max:'2049', step:'1', id:'dd'
        br ''

        label for:'interlaced', 'interlaced'
        input type:'checkbox', id:'interlaced'
        br ''

        canvas id:'lightmap', width:'512', height:'512', style:'display:none'

  coffeescript ->
    setPixel = (imageData, x, y, r, g, b, a) ->
      index = (x + y * imageData.width) * 4
      imageData.data[index] = r
      imageData.data[index + 1] = g
      imageData.data[index + 2] = b
      imageData.data[index + 3] = a

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
      len: ->
        return Math.sqrt @x*@x + @y*@y + @z*@z

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

    map_el = new Image()
    map_el.onload = ->
      colormap_el = new Image()
      colormap_el.onload = ->
        LEFT = 37
        RIGHT = 39
        UP = 38
        DOWN = 40
        left=right=up=down=false

        MAX_D = 512
        LOD_FACTOR = 4
        DETAIL = 1
        interlaced = false
        scr_el = document.getElementById 'scr'

        lod_el = document.getElementById 'lod'
        lod_el.value =  LOD_FACTOR
        lod_el.onchange = ->
          LOD_FACTOR = lod_el.value
          render()

        dd_el = document.getElementById 'dd'
        dd_el.value =  MAX_D
        dd_el.onchange = ->
          MAX_D = dd_el.value
          render()

        interlaced_el = document.getElementById 'interlaced'
        interlaced_el.checked = if interlaced then 'checked' else undefined
        interlaced_el.onchange = ->
          if interlaced_el.checked
            interlaced = true
          else
            interlaced = false
          render()

        c = scr_el.getContext '2d'
        SCR_W = scr_el.width
        SCR_H = scr_el.height


        map_canvas = document.createElement 'canvas'
        map_canvas.setAttribute 'width', map_el.width
        map_canvas.setAttribute 'height', map_el.height
        map_ctx = map_canvas.getContext '2d'
        map_ctx.drawImage map_el, 0,0
        map = map_ctx.getImageData 0,0, map_el.width, map_el.height

        lightmap_canvas = document.getElementById 'lightmap'
        lightmap_ctx = lightmap_canvas.getContext '2d'
        lightmap_ctx.drawImage colormap_el, 0,0
        lightmap = lightmap_ctx.getImageData 0,0, lightmap_canvas.width, lightmap_canvas.height

        compute_lightmap = ->
          x = 0
          nstep = 0.5
          nmax = 64
          while x < lightmap.width
            y = 0
            while y < lightmap.height
              s = 1
              pos = (x + y * map.width) * 4
              h = map.data[pos]*0.25
              n = nstep
              nn = 1
              while h + n < nmax
                pos = (x + ((y + nn)) * map.width) * 4
                if map.data[pos]*0.25 > h + n
                  s = 0.4
                n += nstep
                ++nn
              r = lightmap.data[pos] * s
              g = lightmap.data[pos+1] * s
              b = lightmap.data[pos+2] * s
              s *= 0xff
              setPixel lightmap, x,y, s,s,s, 0x44
              ++y
            ++x
          lightmap_ctx.putImageData lightmap, 0,0
        #compute_lightmap()

        window.cam = new Camera(new Vector(127,64,127), 25, SCR_W,SCR_H)
        cam.setAng(-Math.PI)

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
        
        ch = 0
        d = 0
        maxY = 0
        x = 0
        ray = null
        scr = null
        cast = () ->
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
              r = lightmap.data[pos]
              g = lightmap.data[pos+1]
              b = lightmap.data[pos+2]
              while _y > y and _y < SCR_H
                setPixel(scr, x,_y, r,g,b, 0xff*fog)
                if interlaced
                  setPixel(scr, x+1,_y, r,g,b, 0xff*fog)
                --_y
              maxY = y
          
        cv = new Vector(0,0,0)
        render = ->
          scr = c.createImageData(SCR_W, SCR_H)
          x = 0
          xstep = do -> if interlaced then 2 else 1
          ch = cam.eye.y
          while x < SCR_W
            maxY = SCR_H-1
            ray = cam.getRayFromUV(x, 0)

            d = 15
            lod = 1
            while lod < LOD_FACTOR
              maxd = MAX_D/(LOD_FACTOR-lod)
              while d < maxd
                cast()
                d += DETAIL * lod
              ++lod
            x += xstep
          c.putImageData scr, 0, 0

        animloop = ->
          requestAnimFrame(animloop)
          mustrender = false
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
              mustrender = true
              cam.setAng(cam.ang + 0.035)
            if (right)
              mustrender = true
              cam.setAng(cam.ang - 0.035)

            cam.eye.x += cv.x
            cam.eye.y += cv.y
            cam.eye.z += cv.z
            cv = cv.mul 0.9


          if !mustrender and cv.len() < 0.01
            return
          render()

        render()
        animloop()

      colormap_el.src = 'colormap.jpg'
    map_el.src = 'heightmap.jpg'
