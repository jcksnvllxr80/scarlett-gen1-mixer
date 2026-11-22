# 1st-gen Scarlett USB protocol

Derived from the Linux driver `sound/usb/mixer_scarlett.c`, together with the request helpers in `sound/usb/mixer.c`. Commit `f224bd39` (2026-10-07). Line numbers below refer to `mixer_scarlett.c`.

**Status key:**
- *Linux code*: implemented in the driver.
- *Linux comment*: only described in the driver's header comment (lines 45–74), not implemented.
- *confirmed*: tested on the user's 18i20.

See "Observed on the user's 18i20" for what has been tested so far.

## Request format

Every control is a USB **class request to the audio-control interface** (interface 0), sent over the default control pipe.

| Field | Value |
|---|---|
| `bmRequestType` | `0x21` write (host→device, class, interface) / `0xA1` read |
| `bRequest` | `0x01` = `CUR` (most controls) or `0x03` = `MEM` (meters, sync status, save) |
| `wIndex` | `(entity << 8) \| 0`, where the low byte is the control interface number |
| `wValue` | `(control << 8) \| (channel + idx_off)`, per control below |
| Data | Little-endian. **S16** = 2 bytes signed, **U8** = 1 byte, **U32** = 4 bytes |

The driver adds `idx_off` to `wValue` for both reads and writes (`mixer.c` `request_get_ctl_v2` and `snd_usb_mixer_set_ctl_value`).

## Value encodings

- **Gain / volume (S16):** dB × 256 (8.8 fixed point). Range **−128 dB to +6 dB**. Examples: 0 dB = `0x0000`, −10 dB = `0xF600`, +6 dB = `0x0600`. (Lines 566, 586–588, 734, 744.)
- **Mute (S16):** `0` = unmuted, non-zero = muted. The driver inverts this for its own switches (lines 496, 516).
- **Source IDs (S16):** see the 18i20 table below. `-1` (`0xFFFF`) = Off.

## Controls

| Control | Entity | `bRequest` | `wValue` | Data | Source |
|---|---|---|---|---|---|
| Master volume (all outputs) | `0x0a` | CUR | `0x0200` | S16 dB×256 | Linux code (1190) |
| Master mute (all outputs) | `0x0a` | CUR | `0x0100` | S16 | Linux code (1183) |
| Output bus *b* volume (*b* = 1…20) | `0x0a` | CUR | `0x0200 + b` | S16 dB×256 | Linux code (880–886) |
| Output bus *b* mute | `0x0a` | CUR | `0x0100 + b` | S16 | Linux code (871–877) |
| Output *n* source (*n* = 0…19) | `0x33` | CUR | `0x0000 + n` | S16 source ID | Linux code (889–909) |
| Capture channel *c* source (*c* = 0…17) | `0x34` | CUR | `0x0000 + c` | S16 source ID | Linux code (1363–1372) |
| Mixer input *i* source (*i* = 0…17) | `0x32` | CUR | `0x0600 + i` | S16 source ID (no mixes) | Linux code (1339–1345) |
| Mixer gain, input *i* → mix *m* (*m* = 0…7 = A…H) | `0x3c` | CUR | `(i << 3) \| m` | S16 dB×256 | Linux code (1349–1356) |
| Clock source | `0x28` | CUR | `0x0100` | U8: 1 Internal, 2 S/PDIF, 3 ADAT | Linux code (1375–1378, 222–229) |
| Sample rate | `0x29` | CUR | `0x0100` | U32 Hz (48000 = `80 BB 00 00`) | Linux code (1389–1394) |
| Sync status (read only) | `0x3c` | **MEM** | `0x0002` | U8: 1 = locked | Linux code (1383, 700–724) |
| Input meters (read only) | `0x3c` | **MEM** | `0x0000` | 18 × 2 bytes | Linux comment (69) |
| Mix meters (read only) | `0x3c` | **MEM** | `0x0001` | 8(?) × 2 bytes | Linux comment (70) |
| DAW/PCM meters (read only) | `0x3c` | **MEM** | `0x0003` | count unknown × 2 bytes | Linux comment (71) |
| **Save settings to device** (write) | `0x3c` | **MEM** | `0x005a` | 1 byte `0xA5` | Linux comment (73–74). **Confirmed working** on the 18i20 (2026-11-22), but see *Reads after a power cycle* below. |
| Input *k* impedance (Line / Hi-Z) | `0x01` | CUR | `0x0900 + k` | S16 write; the original software reads 1 byte | Linux code (1207–1216), **disabled for the 18i20** (1157–1162) |
| Input *k* pad (0 / −10 dB) | `0x01` | CUR | `0x0b00 + k` | same as above | Linux code (1217–1226), **disabled for the 18i20** |

The original software also issued unexplained reads: entity `0x29` `wValue 0x0200` (1 byte), and entity `0x2a` `wValue 0x0100` (4 bytes, maybe a second sample rate). Linux comment (63–65).

## 18i20 specifics (`s18i20_info`, lines 1124–1171)

- 18 mixer inputs × 8 mixes (A–H), 18 capture channels, 20 outputs.

**Output buses** (output volume and mute use *b* = 1…20, output source uses *n* = *b* − 1):

| *b* | Output |
|---|---|
| 1–2 | Monitor L/R |
| 3–10 | Line 3–10 |
| 11–12 | S/PDIF 1–2 |
| 13–20 | ADAT 1–8 |

**Source IDs** (offsets `{0, 20, 28, 30, 38}`, `len` 47; enum `start` = −1, so raw value = list item − 1):

| Raw value | Source |
|---|---|
| −1 | Off |
| 0–19 | DAW (computer playback) 1–20 |
| 20–27 | Analog in 1–8 |
| 28–29 | S/PDIF in 1–2 |
| 30–37 | ADAT in 1–8 |
| 38–45 | Mix A–H (only valid for output and capture sources, not mixer inputs) |

**Suggested default mixer-input routing** (`matrix_mux_init`). It's defined in the driver but **never written to the device**:
inputs 1–8 ← Analog 1–8 (20–27), 9–14 ← ADAT 1–6 (30–35), 15–16 ← S/PDIF 1–2 (28–29), 17–18 ← DAW 1–2 (0–1).

## Observed on the user's 18i20 (2026-11-22, reads only)

Using `IOUSBHostDevice` from arm64 (no capture or seize options) while macOS kept streaming audio.

| Control | What happened | Status |
|---|---|---|
| Sync status | `01` = locked | confirmed (read) |
| Clock source | `01` = Internal | confirmed (read) |
| Sample rate | 48000 | confirmed (read) |
| Output source | 2-byte replies; Monitor and Line 3–10 = 38/39 (Mix A/B) | confirmed (read) |
| Output source, unused outputs | Reads **46**, outside the Linux table. Treated as **Off** | observed, needs confirmation |
| Capture source | 2-byte replies; Analog 1–8, S/PDIF 1–2, ADAT 1–8 | confirmed (read) |
| Mixer input source | Replies with **1 byte** even when 2 are requested (e.g. `14` = Analog 1) | confirmed (read) |
| Mixer gains | 2-byte replies; plausible values (+4, 0, −6 dB on mixes A/B) | confirmed (read) |
| Output mute | A 1-byte read gives `00`. A 2-byte read gives `00 0b`, and the second byte is meaningless. **Read mute as 1 byte.** | confirmed (read) |
| Output volume | Monitor and Line 3–6 read −128 dB, Line 7–10 read 0 dB | needs the user to compare with the hardware |
| Input meters (MEM `0x3c/0x0000`) | **36 bytes** = 18 × 2-byte LE values. The first 8 move with signal on analog inputs 1–8 (checked by the user in the app). Scale unknown (quiet inputs read 1–5). Assumed linear, 0xFFFF = 0 dBFS. | confirmed (read); scale and exact order unconfirmed |
| Mix meters (MEM `0x3c/0x0001`) | **16 bytes** = 8 × 2 (mixes A–H). A and B move. | confirmed (read) |
| DAW/PCM meters (MEM `0x3c/0x0003`) | **40 bytes** = 20 × 2 | confirmed (read) |
| CUR `0x29/0x0200` | `01`, meaning unknown | observed |
| CUR `0x2a/0x0100` | `80 bb 00 00` = 48000, so it's a second sample-rate value | observed |
| Hardware monitor knob (HW Control on) | Turning it changed **none** of: output volumes or mutes on buses 0–20, the meters, or `0x29/0x0200` and `0x2a/0x0100`. Polled at about 40 Hz. | not found yet |

**Writes tested:** mixer gain, CUR `0x3c` `0x0100 | node`: input 9 → Mix A set to −60 dB (`00 c4`), read back −60 via `0x0040`, then restored to −∞ (`00 80`). Accepted, and the device stayed healthy. Status: **confirmed (write)**.

**Undocumented entities (don't use):**
- `0x14`: GET with `wValue 0x0a00` **hangs the control handler**, and a power cycle is needed. Slots `0x0100`–`0x0902` all return a single `00`.
- `0x0b`: slots `0x0100`–`0x0102` and `0x0200`–`0x0202` return identical 64-byte blocks of leftover buffer memory, including the UTF-16 text "-DFU". These aren't controls.

**Hardware monitor knob: FOUND.** MEM (`0x03`) read, entity `0x3c`, `wValue 0x0004`, **exactly 4 bytes**. It's polled continuously by Focusrite's own software, with the same length. **Byte 0 = the monitor level number Focusrite's software displays.** It read 32, then 17 after the user turned the knob. Displayed as −32 dB → −17 dB (sign confirmed by the user), so **level = −byte0 dB** and smaller is louder. Byte 1 moves in the opposite direction (probably the raw knob position). Bytes 2–3 have stayed 0 (front-panel buttons?). Over a full sweep, byte 0 ranged 0x11–0x66. Status: confirmed (read). **Never read MEM `0x3c/0x0005`**, which hangs the device.

Earlier searches that didn't find it (kept for reference): the knob was not in any readable register (output volumes and mutes, meters, `0x29/0x0200`, `0x2a/0x0100`, `0x0b`, `0x14`). macOS doesn't expose it either: CoreAudio shows only two controls for the device (a clock-source selector and a boolean output control), and neither changed while the knob was turned. **Conclusion: the knob can't be read on macOS without taking interface 0 from `usbaudiod`.**

**Status interrupt endpoint (interface 0):** opening interface 0 with `IOUSBHostInterface` fails with `0xe00002c9` (exclusive access), because `usbaudiod` owns it. Listening would need the "seize" option, which would stop audio.

**USB capture:** this Mac (Apple Silicon, macOS 27, SIP on) has no `XHC*` capture interfaces, so passive capture isn't available.

**Warning:** a broad scan of unknown GET requests (entities 0x00–0x3f, selectors 1–12, channels 0–2, `wLength` 64) hung the control handler. After it, every request failed with `0xe00002ed` until a power cycle. During the scan, only entities `0x0a`, `0x0b` and `0x14` answered with `wLength` 64. Requests with a longer `wLength` than the control's size seem to be rejected, so always use the documented length.

## Monitor section (from Focusrite's software traffic, 2026-11-22)

Logged while the user clicked each MixControl button on and off. All are writes (`bmRequestType 0x21`) unless marked.

| Control | Request | Data | Read back? |
|---|---|---|---|
| Dim (−18 dB) | MEM `0x3c` `0x0006` | 1 byte: `01` on, `00` off | No. **Write-only**; don't read it |
| Mute (all monitored outputs) | MEM `0x3c` `0x0005` | 1 byte: `01` on, `00` off | No. **Never read it**: reading it hangs the device |
| LMute / RMute | CUR `0x0a` `0x0101`–`0x010a` (output mutes) | S16: `1` muted, `0` unmuted. Only the odd (L) or even (R) outputs under monitor control are changed | Yes (1 byte) |
| Mono (sum pairs) | CUR `0x14` `0x0a01`–`0x0a05`, one per line-output pair (1/2 … 9/10) | 1 byte: `01` sum, `00` off. Set for the pairs under monitor control | No. Don't read; `0x0a00` hangs the device |
| −20 dB Pad (Monitor 1/2) | CUR `0x14` `0x0801` | 1 byte: `01` on, `00` off | **Yes**: MixControl reads `0x14/0x0801` (1 byte) when it connects |
| Hardware knob controls these outputs | MEM `0x3c` `0x000a` | 4 bytes LE bitmask, bit *n* = line output *n*+1 (e.g. `3f 00 00 00` = outputs 1–6). Set to `0` when HW Control is off | No |
| (unknown, same family) | MEM `0x3c` `0x000b`, `0x000c` | 4-byte masks, written `ff 03 00 00` at connect | No |
| Software monitor level (HW Control off) | CUR `0x0a` `0x0201`… (output volumes) | S16 dB×256 (e.g. `9c cd` = −50.4 dB), written to the controlled outputs | Yes |
| Mixer gain writes | CUR `0x3c` `0x0100 \| node` (node = input × 8 + mix) | S16 dB×256 (`00 80` = −∞, `00 fa` = −6 dB) | Reads used `0x00nn` |

MixControl also reads, once at connect: MEM `0x3c/0x00f0` (1 byte, `01`), and CUR `0x01` `0x0901`, `0x0902`, `0x0803` and `0x0804` (1 byte, no data returned).

**Device → app:** the only hardware-changeable states MixControl polls are the meters, the monitor knob (MEM `0x0004`) and the sync status. Dim, Mute and Mono aren't readable, so the app must remember them itself.

## Notes for macOS

- **Sample rate:** Linux forces 48 kHz when it loads (lines 1389–1394). On macOS, `usbaudiod` owns audio streaming, so change the rate through CoreAudio (`kAudioDevicePropertyNominalSampleRate`) rather than this request. Treat entity `0x29` as read-only until tested.
- **Never use interface 5 (DFU)** or anything firmware-related.
- **"Save to device"** writes non-volatile memory. Get the user's approval before sending it.
- The Linux header says gains "sometimes" use 4 bytes (line 59). The code always uses 2.

## Bulk writes (Open Setup)

Confirmed on the 18i20 (2026-11-22): opening a setup sent **208 writes in about one second** (routing, sources, mixer gains, mutes, monitor controls). The device accepted them all, stayed connected, and the restored state matched the file.

## Save to Interface and reads after a power cycle (2026-11-22)

- **Save works.** MEM `0x3c/0x005a` = `A5`: after Save to Interface (with the left monitor outputs muted), a power cycle kept the left monitor muted (heard by the user).
- **But the app showed it unmuted** after reconnecting: its one full read at connect returned "unmuted" for buses 1/3/5.
- **Confirmed (clean run, 23:06):** L muted, Save to Interface, nothing sent afterwards, power cycle, waited about 10 s. The left monitor stayed muted, but a read-only dump reported buses 1/3/5 **unmuted**. **After a power-up the 18i20 runs its saved settings but reads back defaults** (shown for output mutes; gains are probably the same). Reads are only correct for controls written since power-up.
- **Reads work for anything written since power-up:** after the app re-sent the left mute (23:10), the same read returned muted (`M`).
- **Focusrite's MixControl doesn't read the saved state either.** After a power cycle with the left mute saved (left audibly muted), opening MixControl unmuted it: on connect, MixControl sends its own stored copy of the settings rather than reading them. Linux does the same. So there is probably no register that reports the restored settings; apps keep their own copy and re-send it.
