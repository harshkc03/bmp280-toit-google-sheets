// Copyright (C) 2020 Toitware ApS. All rights reserved.

// Driver for BMP280 Pressure and Temperature sensor.

import binary
import serial.device as serial
import serial.registers as serial

class Bmp280:
  static I2C_ADDRESS     ::= 0x76
  static I2C_ADDRESS_ALT ::= 0x77

  static DIG_T1_REG_ ::= 0x88
  static DIG_T2_REG_ ::= 0x8A
  static DIG_T3_REG_ ::= 0x8C

  static DIG_P1_REG_ ::= 0x8E
  static DIG_P2_REG_ ::= 0x90
  static DIG_P3_REG_ ::= 0x92
  static DIG_P4_REG_ ::= 0x94
  static DIG_P5_REG_ ::= 0x96
  static DIG_P6_REG_ ::= 0x98
  static DIG_P7_REG_ ::= 0x9A
  static DIG_P8_REG_ ::= 0x9C
  static DIG_P9_REG_ ::= 0x9E

  static DIG_H1_REG_ ::= 0xA1
  static DIG_H2_REG_ ::= 0xE1
  static DIG_H3_REG_ ::= 0xE3
  static DIG_H4_REG_ ::= 0xE4
  static DIG_H5_REG_ ::= 0xE5
  static DIG_H6_REG_ ::= 0xE7

  static REGISTER_CHIPID_       ::= 0xD0
  static REGISTER_VERSION_      ::= 0xD1
  static REGISTER_RESET_        ::= 0xE0
  static REGISTER_CAL26_        ::= 0xE1
  static REGISTER_CONTROL_HUM_  ::= 0xF2
  static REGISTER_STATUS_       ::= 0xF3
  static REGISTER_CONTROL_MEAS_ ::= 0xF4
  static REGISTER_CONFIG_       ::= 0xF5
  static REGISTER_PRESSUREDATA_ ::= 0xF7
  static REGISTER_TEMPDATA_     ::= 0xFA
  static REGISTER_HUMIDDATA_    ::= 0xFD

  reg_/serial.Registers ::= ?

  dig_T1_ := null
  dig_T2_ := null
  dig_T3_ := null

  dig_P1_ := null
  dig_P2_ := null
  dig_P3_ := null
  dig_P4_ := null
  dig_P5_ := null
  dig_P6_ := null
  dig_P7_ := null
  dig_P8_ := null
  dig_P9_ := null

  dig_H1_ := null
  dig_H2_ := null
  dig_H3_ := null
  dig_H4_ := null
  dig_H5_ := null
  dig_H6_ := null

  constructor dev/serial.Device:
    reg_ = dev.registers

  on:
    // The official Bosch sample tries to read the CHIP ID
    // 5 times and pauses for one millisecond between the
    // reads. We do the same.
    tries := 5
    while (reg_.read_u8 REGISTER_CHIPID_) != 0x58:
      tries--
      if tries == 0: throw "INVALID_CHIP"
      sleep --ms=1

    reset_

    read_calibration_data_

    // Sleep mode, we only measure when needed.
    reg_.write_u8 REGISTER_CONTROL_MEAS_ 0b000_000_00

    reg_.write_u8 REGISTER_CONFIG_ 0b000_000_0_0
    reg_.write_u8 REGISTER_CONTROL_HUM_ 0b00000_001 // Set before CONTROL (DS 5.4.3)

  off:
    reg_.write_u8 REGISTER_CONTROL_MEAS_ 0b000_000_00

  read_temperature -> float:
    t_fine := measure_

    temperature := (t_fine * 5 + 128) >> 8
    return temperature / 100.0

  read_pressure -> float:
    t_fine := measure_

    adc_P := reg_.read_u24_be REGISTER_PRESSUREDATA_
    if adc_P == 0x800000: throw "BMP280: sensor is busy"

    adc_P >>= 4

    var1 := t_fine - 128000
    var2 := var1 * var1 * dig_P6_
    var2 = var2 + ((var1 * dig_P5_) << 17)
    var2 = var2 + (dig_P4_ << 35)
    var1 = ((var1 * var1 * dig_P3_) >> 8) + ((var1 * dig_P2_) << 12)
    var1 = (((1 << 47) + var1) * dig_P1_) >> 33

    if var1 == 0: return 0.0 // avoid exception caused by division by zero

    p := 1048576 - adc_P
    p = (((p << 31) - var2) * 3125) / var1
    var1 = (dig_P9_ * (p >> 13) * (p >> 13)) >> 25
    var2 = (dig_P8_ * p) >> 19

    p = ((p + var1 + var2) >> 8) + (dig_P7_ << 4)
    return p/256.0

  read_calibration_data_:
    dig_T1_ = reg_.read_u16_le DIG_T1_REG_
    dig_T2_ = reg_.read_i16_le DIG_T2_REG_
    dig_T3_ = reg_.read_i16_le DIG_T3_REG_

    dig_P1_ = reg_.read_u16_le DIG_P1_REG_
    dig_P2_ = reg_.read_i16_le DIG_P2_REG_
    dig_P3_ = reg_.read_i16_le DIG_P3_REG_
    dig_P4_ = reg_.read_i16_le DIG_P4_REG_
    dig_P5_ = reg_.read_i16_le DIG_P5_REG_
    dig_P6_ = reg_.read_i16_le DIG_P6_REG_
    dig_P7_ = reg_.read_i16_le DIG_P7_REG_
    dig_P8_ = reg_.read_i16_le DIG_P8_REG_
    dig_P9_ = reg_.read_i16_le DIG_P9_REG_

    dig_H1_ = reg_.read_u8 DIG_H1_REG_
    dig_H2_ = reg_.read_i16_le DIG_H2_REG_
    dig_H3_ = reg_.read_u8 DIG_H3_REG_
    dig_H4_ = ((reg_.read_i8 DIG_H4_REG_) << 4) | ((reg_.read_u8 DIG_H4_REG_+1) & 0xF)
    dig_H5_ = ((reg_.read_i8 DIG_H5_REG_+1) << 4) | ((reg_.read_u8 DIG_H5_REG_) >> 4)
    dig_H6_ = reg_.read_i8 DIG_H6_REG_

  wait_for_measurement_:
    16.repeat:
      val := reg_.read_u8 REGISTER_STATUS_
      if val & 0b1001 == 0: return
      sleep --ms=it + 1  // Back off slowly.
    throw "BMP280: Unable to measure"

  measure_:
    reg_.write_u8 REGISTER_CONTROL_MEAS_ 0b001_001_01

    // Wait for measurement to start; typical time for full measurement using
    // 1x oversampling on all sensors.
    //   1 + [2 * 1] + [2 * 1 + 0.5] + [2 * 1 + 0.5] = 8
    sleep --ms=8
    // Wait until measurement is done.
    wait_for_measurement_

    adc_T := reg_.read_u24_be REGISTER_TEMPDATA_

    adc_T >>= 4;

    var1 := (((adc_T >> 3) - (dig_T1_ << 1)) * dig_T2_) >> 11
    var2 := (adc_T >> 4) - dig_T1_
    var2 = (((var2 * var2) >> 12) * (dig_T3_)) >> 14

    return var1 + var2

  reset_:
    reg_.write_u8 REGISTER_RESET_ 0xB6

    // Wait until reset is done.
    8.repeat:
      sleep --ms=2  // As per data sheet - Table 1, startup time is 2 ms.
      catch:
        val := reg_.read_u8 REGISTER_STATUS_
        if val & 0b1 == 0: return
    throw "BMP280: Unable to reset"
