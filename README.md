# ws2812b_mm

Minimalistic WS2812B LED driver implemented as an FPGA IP core with Avalon-MM interface, designed for integration with Nios V systems.

---

<!--
## 📸 Overview

*(add logic analyzer screenshot / LED strip photo here — highly recommended)*
---
-->

## 🎯 Purpose

This project implements a low-level WS2812B driver as an FPGA IP core, with focus on:

* precise signal timing
* deterministic hardware-based waveform generation
* efficient LED data handling (double buffering)
* perceptually correct brightness control (gamma correction)
* easy integration into SoC designs

---

## ⚙️ Features

* FPGA-based WS2812B driver (cycle-accurate)
* Avalon-MM slave interface
* CPU-controlled via memory-mapped registers
* **Double buffering (tear-free updates)**
* **Brightness control**
* **Gamma correction (perceptual linearity)**
* Deterministic timing (no software jitter)
* Suitable for integration with Nios V systems
* Scalable and hardware-efficient design

---

## 🧠 How it works

WS2812B LEDs use a **single-wire protocol with strict timing requirements**.

Each bit is encoded as a pulse with specific high/low durations:

* logical `0` → short HIGH pulse
* logical `1` → longer HIGH pulse

The controller generates a continuous stream of bits representing RGB values for each LED.

### Flow

1. CPU writes pixel data to **back buffer** via Avalon-MM
2. Optional brightness and gamma correction is applied
3. Frame is committed (buffer copying)
4. Hardware logic reads from **front buffer**
5. Precise waveform is generated and transmitted
6. LEDs latch new data

### Key idea

The core challenges are:

* generating **cycle-accurate waveforms**
* eliminating jitter (hardware-based timing)
* ensuring **glitch-free updates (double buffering)**
* providing **perceptually correct brightness (gamma correction)**

In FPGA-based systems, the driver is implemented as an IP core with an Avalon-MM interface, allowing a soft-core CPU (e.g. Nios V) to control the LED strip via memory-mapped registers.

---

## 🏗️ Architecture

### System diagram

```id="a7r2kp"
[CPU (Nios V)] → [Avalon-MM bus] → [WS2812B IP core]
                                         ↓
                              [Back Buffer / Front Buffer]
                                         ↓
                              [Gamma / Brightness]
                                         ↓
                              [Timing generator] → [GPIO]
```

### Modules

#### FPGA / IP core

* Avalon-MM slave interface
* **double framebuffer (front/back buffer)**
* brightness scaling unit
* gamma correction block
* timing generator (cycle-accurate waveform)
* serializer (RGB → bitstream)

#### Software (optional)

* running on Nios V
* writes pixel data to back buffer
* triggers buffer swap
* sets brightness (optional)

---

## 🔌 Hardware

### Components

* FPGA: Intel FPGA (e.g. Cyclone series)
* LEDs: WS2812B strip or compatible

### Notes

* typical voltage: 5V (LEDs)
* level shifting may be required (FPGA → LED)
* signal integrity matters (short wires, proper grounding)

---

### Integration

The IP core can be integrated using:

* Platform Designer (Qsys)
* connected to Nios V soft-core CPU

Example system:

```id="jpnx7n"
[Nios V CPU] ↔ [Avalon-MM interconnect] ↔ [WS2812B IP]
```

### Registers

* DATA registers – write RGB values (back buffer)
* CONTROL/STATUS register:

  * start refresh (write)
  * set brightness (write/read)
  * read number of LED's supported (read)
  * busy/ready flag (ready)

### Framebuffer

* **Back buffer** – written by CPU
* **Front buffer** – used for transmission
* buffer copying ensures **tear-free updates**

### Gamma correction

* implemented as LUT (look-up table)
* maps linear input values → perceptual brightness

### Timing

* generated fully in hardware
* deterministic (cycle-based)
* independent of CPU load

---

## 🧾 Protocol & timing

WS2812B protocol is **timing-sensitive**, not clocked.

Typical bit encoding:

* T0H ≈ 0.35 µs
* T1H ≈ 0.7 µs
* total bit time ≈ 1.25 µs

Reset/latch:

* LOW for >50 µs

---

### Key concepts

* memory-mapped I/O (Avalon-MM)
* double buffering (safe updates)
* hardware-accelerated waveform generation
* CPU-independent timing

---

## ▶️ Getting started

### Requirements

* Intel FPGA board
* WS2812B LED strip
* Quartus / Platform Designer
* (optional) Nios V toolchain

---

### FPGA build

1. Open project in Quartus
2. Add IP core to Platform Designer system
3. Connect Avalon-MM interface
4. Compile design
5. Program FPGA

---

### Firmware (optional)

1. Create Nios V application
2. Map IP core base address
3. Write pixel data and trigger frame update

---

### Run

1. Power FPGA and LED strip
2. Send pixel data from CPU
3. Trigger buffer refresh
4. Start transmission
5. LEDs update without visible artifacts

---

## ⚙️ Configuration

Configurable aspects:

* number of LEDs
* brightness level
* gamma curve (LUT)
* clock frequency (affects timing)

---

## ⏱️ Timing & determinism

* timing generated in FPGA (clock-driven)
* no dependency on CPU execution
* deterministic waveform generation
* zero jitter compared to software implementations

Additional guarantees:

* **double buffering prevents visual glitches**
* constant frame timing independent of CPU load

---

## 🔐 Safety

⚠️ Electrical considerations:

* high current for long LED strips
* ensure proper power supply
* avoid voltage drops

⚠️ Design considerations:

* incorrect timing → undefined LED behavior
* verify gamma/brightness scaling does not overflow

---

## 🧪 Testing

Recommended methods:

* logic analyzer (verify waveform timing)
* oscilloscope (pulse width validation)
* visual validation of:

  * brightness linearity
  * absence of flicker (double buffering)

---

## 🐛 Known issues

* requires correct clock configuration
* gamma LUT must match LED characteristics
* register interface may need customization per system

---

## 🚀 Future improvements

* per-channel brightness control
* programmable gamma curves
* streaming (DMA-like) interface

---

## 📚 References

* WS2812B datasheet
* Intel Avalon Interface Specification
* Quartus / Platform Designer documentation

---

## 📜 License

MIT
