express = require 'express'
ejs = require 'ejs'
arDrone = require("ar-drone")

# client = arDrone.createClient();
# control = client._udpControl
control = arDrone.createUdpControl()
navdataStream = arDrone.createUdpNavdataStream();

start = Date.now()
ref = {}
pcmd = {}
navdata = {}
app = express()

app.configure ->
  app.use(express.bodyParser())
  app.set('dirname', __dirname)
  app.use(app.router)
  app.use(express.static(__dirname + "/public/"))
  app.use(express.errorHandler({ dumpExceptions: true, showStack: true}))
  app.set('views',__dirname + "/views/")

app.get "/", (req,res) ->
  res.render 'index.ejs'

port = process.env.PORT || 8080
app.listen port
console.log "Listening on Port '#{port}'"

class Drone
  constructor: (speed) ->
    @speed = speed
    @accel = 0.01

  takeoff: ->
    console.log "Takeoff ..."
    ref.emergency = false
    ref.fly = true

  land: ->
    console.log "Landing ..."
    ref.fly = false
    pcmd = {}

  stop: ->
    pcmd = {}

  commands: (names) =>
    pcmd = {}
    for name in names
      pcmd[name] = @speed
    console.log 'PCMD: ', pcmd
  
  increaseSpeed: =>
    @speed += @accel
    console.log @speed

  decreaseSpeed: =>
    @speed -= @accel
    console.log @speed

setInterval (->
  control.ref ref
  control.pcmd pcmd
  control.flush()
), 30

drone = new Drone(0.5)

drone.speed = 0.4

console.log drone 

io = require("socket.io").listen(8081)
io.set('log level', 1)
io.sockets.on "connection", (socket) ->
  socket.on "takeoff", drone.takeoff
  socket.on "land", drone.land
  socket.on "stop", drone.stop
  socket.on "command", drone.commands
  socket.on "increaseSpeed", drone.increaseSpeed
  socket.on "decreaseSpeed", drone.decreaseSpeed
  emitDroneTelemetry socket

# Push telemetry to the clients in an orderly fashion
emitDroneTelemetry = (socket) ->
  setInterval(() -> 
    socket.emit 'navdata', navdata
  , 1000)
    
# Splurge requests for data over UDP
requestNavdata = (index) -> 
  count = 0
  id = setInterval (->
    control.config('general:navdata_demo', 'TRUE')
    count++
    clearInterval(id) if count > 20
  ), 30
  
# Set up the Drone to server telemetry pipe  
setupNavdataStream = () ->  
  requestNavdata() 
  navdataStream.removeAllListeners()
  navdataStream.resume()
  navdataStream.on 'data', (data) ->
    navdata = data    

# Start hoovering up the navdata from the drone
setupNavdataStream()
