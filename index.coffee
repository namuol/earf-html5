html ->
  body ->
  canvas id:'canvas1', width:'100', height:'100', 'Random Canvas'

  coffeescript ->
    # shim layer with setTimeout fallback
    window.requestAnimFrame = do ->
      return  window.requestAnimationFrame       ||
              window.webkitRequestAnimationFrame ||
              window.mozRequestAnimationFrame    ||
              window.oRequestAnimationFrame      ||
              window.msRequestAnimationFrame     ||
              (callback) ->
                window.setTimeout callback, 1000 / 60

    setPixel = (imageData, x, y, r, g, b, a) ->
      index = (x + y * imageData.width) * 4
      imageData.data[index + 0] = r
      imageData.data[index + 1] = g
      imageData.data[index + 2] = b
      imageData.data[index + 3] = a

    render = ->
      element = document.getElementById("canvas1")
      c = element.getContext("2d")
      width = parseInt(element.getAttribute("width"))
      height = parseInt(element.getAttribute("height"))
      imageData = c.createImageData(width, height)
      i = 0
      while i < 10000
        x = parseInt(Math.random() * width)
        y = parseInt(Math.random() * height)
        r = parseInt(Math.random() * 256)
        g = parseInt(Math.random() * 256)
        b = parseInt(Math.random() * 256)
        setPixel imageData, x, y, r, g, b, 0xff
        i++
      c.putImageData imageData, 0, 0

    animloop = ->
      requestAnimFrame animloop
      render()

    animloop()
