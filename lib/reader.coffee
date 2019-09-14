path   = require 'path'
_      = require 'lodash'
async  = require 'async'
HID    = require 'node-hid'
When   = require 'when'

tables = require path.join( global.__base, "configs", "tables" )

# tag_length  = 13
tag_length  = 10
# how many empty reads before we can assume input has ended?
empty_reads_mark_finish = 5

### RFID Reader

Bus 001 Device 003: ID 16c0:27db Van Ooijen Technische Informatica Keyboard
Device Descriptor:
  bLength                18
  bDescriptorType         1
  bcdUSB               1.10
  bDeviceClass            0 (Defined at Interface level)
  bDeviceSubClass         0
  bDeviceProtocol         0
  bMaxPacketSize0         8
  idVendor           0x16c0 Van Ooijen Technische Informatica
  idProduct          0x27db Keyboard
  bcdDevice            0.01
  iManufacturer           1 HXGCoLtd
  iProduct                0
  iSerial                 0
  bNumConfigurations      1
  Configuration Descriptor:
    bLength                 9
    bDescriptorType         2
    wTotalLength           41
    bNumInterfaces          1
    bConfigurationValue     1
    iConfiguration          0
    bmAttributes         0xa0
      (Bus Powered)
      Remote Wakeup
    MaxPower              500mA
    Interface Descriptor:
      bLength                 9
      bDescriptorType         4
      bInterfaceNumber        0
      bAlternateSetting       0
      bNumEndpoints           2
      bInterfaceClass         3 Human Interface Device
      bInterfaceSubClass      0 No Subclass
      bInterfaceProtocol      0 None
      iInterface              0
        HID Device Descriptor:
          bLength                 9
          bDescriptorType        33
          bcdHID               1.10
          bCountryCode            0 Not supported
          bNumDescriptors         1
          bDescriptorType        34 Report
          wDescriptorLength      61
         Report Descriptors:
           ** UNAVAILABLE **
      Endpoint Descriptor:
        bLength                 7
        bDescriptorType         5
        bEndpointAddress     0x81  EP 1 IN
        bmAttributes            3
          Transfer Type            Interrupt
          Synch Type               None
          Usage Type               Data
        wMaxPacketSize     0x0008  1x 8 bytes
        bInterval              10
      Endpoint Descriptor:
        bLength                 7
        bDescriptorType         5
        bEndpointAddress     0x01  EP 1 OUT
        bmAttributes            3
          Transfer Type            Interrupt
          Synch Type               None
          Usage Type               Data
        wMaxPacketSize     0x0008  1x 8 bytes
        bInterval              10
Device Status:     0x0000
  (Bus Powered)
###


buffer = ''
empty_reads = 0
listen_for_empty = false

#try to get RFID reader
getRFIDReader = ->
  deferred = When.defer()

  devices = HID.devices()
  # console.log(devices);
  rfidreader = _.find devices, (d) -> d.manufacturer is 'HXGCoLtd'

  if rfidreader? and rfidreader.path?
    deferred.resolve new HID.HID( rfidreader.path )
  else
    deferred.reject new Error('no rfid reader found')

  deferred.promise


readIDs = (data, cb) ->
  shift = data[0] is 2
  key = data[2]
  table = if shift then tables.shift_hid else tables.hid

  # console.log typeof key, key

  if table?[key]?
    buffer += table[key]
    # start listening for empty reads
    empty_reads = 0
    listen_for_empty = true

  else if data[0] is 0 and data[2] is 0
    #read was empty
    empty_reads += 1 if listen_for_empty


  # if buffer.length >= tag_length
  # if we hit X empty reads, stop listening and output RFID buffer string
  if empty_reads >= empty_reads_mark_finish
    empty_reads = 0
    listen_for_empty = false
    console.log "rfid is:".green, buffer
    buffer = ''

  # console.log buffer.blue

deviceError = (err, cb) ->
  console.error 'RFID read error'.red, err



module.exports = (idReadCb=null, errorCB=null) ->
  #get rfid device
  getRFIDReader().then (device) ->
    #setup device events
    device.on "data", (data) ->
      readIDs data, idReadCb

    device.on "error", (err) ->
      deviceError err, errorCB

  .catch (err) ->
    console.error 'No RFID reader found'.red, err
    process.exit(0)
