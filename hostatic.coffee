require('zappa') ->
  @app.use @express.static __dirname + '/build'
