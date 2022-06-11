// Import libraries for HTTPS.
import certificate_roots
import http
import net
import encoding.json

// Import libraries for BMP280 sensor
import gpio
import i2c
import bmp280 as drivers

HOST ::= "script.google.com"
APP_ID ::= "< Your Web app Deployment ID >" // Webapp deployment ID.
EMAIL_ID ::= "< Your e-mail address >" // Email address for sending alerts.
TEMP_THRESHOLD ::= "28" // Temperature threshold in degrees.

// Sends the given temperature $temp and pressure $pres to the Google server.
send_to_spreadsheet temp pres:
  network := net.open
  client := http.Client.tls network
      --server_name=HOST
      --root_certificates=[certificate_roots.GLOBALSIGN_ROOT_CA]
  
  parameters := "email=$EMAIL_ID&thresh=$TEMP_THRESHOLD&id=Sheet1&Temperature=$temp&Pressure=$pres"
  response := client.get HOST "/macros/s/$APP_ID/exec?$parameters"

  // Drain the response.
  while response.body.read:

main:
  catch --trace:
    // Create an object for BMP280 sensor class
    bus := i2c.Bus
      --sda=gpio.Pin 21
      --scl=gpio.Pin 22
    device := bus.device drivers.I2C_ADDRESS
    bmp := drivers.Bmp280 device

    // Turn on BMP280 sensor.
    bmp.on

    temp := bmp.read_temperature
    pres := bmp.read_pressure

    // Debug.
    print "Temperature: $temp C,  Pressure: $pres Pa"

    // Store current temperature and pressure readings.
    send_to_spreadsheet temp pres
    