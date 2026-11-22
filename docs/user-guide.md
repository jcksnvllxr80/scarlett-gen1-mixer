# User guide

## How the mixer works

### The three stages

```
 INPUTS              MIXES                 OUTPUTS
 (what comes in)     (blends you make)     (where it goes out)

 Vocal   ─┐
 Guitar  ─┤
 Bass    ─┼───────►  Mix 1/2  ──────────►  Drummer in-ears
 Keys    ─┤          Mix 3/4  ──────────►  Singer in-ears
 Kick    ─┤          Mix 5/6  ──────────►  Guitarist in-ears
 Click   ─┘          Mix 7/8  ──────────►  Room speakers

          ▲                          ▲
     FADERS decide            MATRIX decides
     how much of each         which mix each
     input is in each mix     output plays
```

- **Inputs:** everything plugged into the interface (Analog 1–8, S/PDIF, ADAT), plus playback from the computer (DAW 1–20).
- **Mixes:** blends of the inputs. **Every input can be in every mix**, each at its own level. There are 8 mono mixes, normally used as 4 stereo mixes (1/2, 3/4, 5/6, 7/8).
- **Outputs:** the sockets that in-ears, headphones and speakers plug into.

### Think of it as blenders and cables

- **A mix is a blender.** You pour in click, guitar, bass and drums, each at the level you set with the faders, and get one blended signal out.
- **An output is a cable.** It plugs into **one** blender: one mix. That's why each patch-bay row has only one lit cell.
- **The patch bay just plugs cables into blenders.** The blending itself happens on the fader tabs.

You can also plug an output straight into **a single input or DAW channel** (the In and DAW columns). Then it plays **only that one thing**, with no blend.

### Example: a band on in-ears

```
 INPUTS          FADERS (one tab per person)               MIXES        PATCH BAY          WHO HEARS IT

 Vocal  (In1) ─┐
 Guitar (In2) ─┤  Mix 1/2 tab: click↑ guitar↑ bass↑ kick↑ ─► Mix 1/2 ─► Line 3/4 ← Mix1/Mix2 ─► Drummer
 Bass   (In3) ─┤
 Kick   (In4) ─┼► Mix 3/4 tab: vocal↑↑ guitar- keys-      ─► Mix 3/4 ─► Line 5/6 ← Mix3/Mix4 ─► Singer
 Keys   (In5) ─┤
 Click (DAW1) ─┼► Mix 5/6 tab: guitar↑↑ vocal- click↑     ─► Mix 5/6 ─► Line 7/8 ← Mix5/Mix6 ─► Guitarist (Phones 1)
               │
               └► Mix 7/8 tab: everything balanced        ─► Mix 7/8 ─► Monitor  ← Mix7/Mix8 ─► Room speakers
```

**The guitar reaches everyone.** It doesn't do it through the patch bay; it goes into **every mix** through the faders. It's loud on the guitarist's tab, quieter on the drummer's, and low on the singer's.

**Setting it up:**
1. **Channel sources (top of each fader strip):** set them once, e.g. 1·2 = Vocal/Guitar, 3·4 = Bass/Kick, 17·18 = DAW 1/2 (click). Sources are the same in every mix.
2. **One mix tab per person:** click a person's tab (e.g. **Mix 1/2** for the drummer) and raise the faders for what *they* want to hear.
3. **Patch bay:** plug each person's output into their mix, e.g. **Line 3/4 L ← Mix1** and **Line 3/4 R ← Mix2**.

## Monitor section (top)

| Control | What it does |
|---|---|
| **Level ring** | Shows the front-panel monitor knob's level live (e.g. −54 dB). Turn the knob on the interface; the ring follows. |
| **Buttons** (2 rows) | DIM · MUTE · MONO on top, L · R · −20 PAD below. |
| **DIM** | Lowers the monitored outputs by 18 dB. |
| **MUTE** | Mutes the monitored outputs. |
| **L** / **R** | Mutes the left (odd-numbered) or right (even-numbered) monitored outputs. |
| **MONO** | Sums left and right into both sides on the monitored output pairs. |
| **−20 PAD** | Lowers Monitor 1/2 by 20 dB, so the knob has more useful range with loud powered speakers. |
| **Output lights 1–10** (under the buttons) | One per line output (1/2 = Monitor L/R, 3–10 = Line 3–10). Lit = something is routed to it and it isn't muted. Hover for its source. They aren't level meters. |
| **CLOCK** | The sample rate (44.1 · 48 · 88.2 · 96 kHz) and clock source (INTERNAL · S/PDIF · ADAT); the lit button is the current one. Same settings as Audio MIDI Setup, and changes made there show up here. Changing the rate briefly interrupts audio. |
| **APPEARANCE** | DARK · AUTO · LIGHT. AUTO follows macOS. |
| **SETUP** | The open setup's name ("Untitled" if none), with an **amber dot** when there are unsaved changes. **Open…**, **Save**, **Save As…** and **Save to Interface…** work as described in [Setups](#setups-save-and-recall). |
| **Status** (right) | The connected interface, and **● LOCKED** when its clock is locked to the chosen source (checked about once a second). On INTERNAL it's always locked. |

"Monitored outputs" are Line outputs 1–6 (Monitor 1/2, Line 3/4, Line 5/6), which follow the front-panel knob.

The interface can't report DIM, MUTE and MONO back, so the app remembers them. Setup files store them too.

## Mixer section (middle)

### Mix tabs

| Control | What it does |
|---|---|
| **Mix 1/2 … Mix 7/8** | Picks which mix the faders below are editing. Each mix has its own colour; the selected tab lights up and opens into the outline around the faders it controls. |
| **⚭** (on a tab) | Switches that pair between one **stereo** mix (e.g. Mix 1/2, icon in colour) and two **mono** mixes (Mix 1 and Mix 2, each with its own tab, icon grey). Use mono for a single wedge or a one-ear feed. |

### Channel pairs

The 18 mixer channels are shown as 9 boxes, **1·2 … 17·18**. Each box is a stereo pair by default.

| Control | What it does |
|---|---|
| **L / R source labels** (top) | Click to choose what feeds that channel: Off, an analog input, S/PDIF, ADAT, or a DAW channel. **Sources are shared by all mixes**; only the levels differ per mix. |
| **Pan ring** | Stereo mixes only. A green arc grows toward the side you pan to; the tick at the top lights green at centre. Drag around the ring (down the left side = further left); double-click to centre. On a stereo pair it works as **balance**. Mono mixes show **MONO** instead. |
| **Fader** | Sets the channel's level in the selected mix, from −∞ up to +6 dB. Drag; double-click for 0 dB. |
| **Meters** (L / R) | The live level of the channel's source. They read the source itself, not the fader. |
| **dB readout** | The current fader level. "—" means the channel's source is Off. |
| **M** | Mutes the channel in the selected mix (remembers its level; click again to restore). |
| **S** | Solos the channel in the selected mix: mutes the other channels in that mix until you click it again. |
| **⚭ stereo / ⚭ mono ×2** (bottom of a box) | Joins the pair into one stereo strip (odd = left, even = right), or splits it into two mono strips, each with its own fader and pan. |

Dimmed boxes have no source (Off), so they add nothing to any mix.

## Patch bay (bottom)

Rows are the **outputs**. Columns are what they can play:

| Column group | What it is |
|---|---|
| **MIXES: Mix1–Mix8** | The mixes you build with the faders. Mix1/Mix2 are the left/right halves of Mix 1/2, and so on. |
| **INPUTS: In1–In8** | An analog input played on its own, without the mixer. |
| **DAW (COMPUTER PLAYBACK): DAW1–DAW8** | A computer playback channel played on its own, without the mixer. |
| **other** | Shows the current source if it isn't in the columns (S/PDIF, ADAT, DAW 9–20), or "off". |

| Action | What it does |
|---|---|
| **Click a cell** | That output plays that column; the cell lights up in its group's colour. The row's previously lit cell turns off. |
| **Click a lit cell** | Turns that output off. |
| **Shift-click** | Fills a column: the anchor cell's source (the last cell you clicked, outlined) goes to every output between the anchor row and the row you shift-click. |
| **Drag a box** | Starting on a **lit** cell (red box): turns off every lit cell inside the box. Starting on an **unlit** cell (box in that source's colour): routes that source to every output row the box covers. |
| **Click an In or DAW label** | Rename it (e.g. "Kick", "Click"). The name also appears on the fader strips. **Reset** restores the default. |
| **Right-click a column label** | Info: what the source is, which outputs play it, and which mixer channels use it (for mixes: which channels are audible in it). |
| **Hover** | A tooltip at the cell (output ← source), the full description above the matrix, and the row and column labels highlighted in the source's colour. |

**Headphones:** front-panel Headphones 1 plays whatever Line 7/8 plays, and Headphones 2 follows Line 9/10.

**Why only one lit cell per row?** Each output socket carries one signal. Blending happens in the mixes; the patch bay only connects.

## Setups (save and recall)

There are two kinds of saving:

| | What it does | When to use it |
|---|---|---|
| **Setup file** (Open / Save / Save As) | Saves everything to a `.scarlettmix` file on your Mac: routing, what's sent to the computer, channel sources, all mixer levels, output mutes (L / R), DIM/MUTE/MONO/PAD, stereo links, mono mixes and your column names. **Opening** a setup sends it all to the interface. | Several setups for different jobs: "Band rehearsal", "Home recording", "Podcast" |
| **Save to Interface…** | Stores the interface's **current** settings in its own memory, after a confirmation. It starts up with them after a power cycle, even with no computer. | Your everyday default, or using the interface as a stand-alone mixer |

- Setups are kept in **Documents ▸ Scarlett Gen 1 Mixer**. Open and Save As always start there, and **File ▸ Show Setups Folder** opens it in Finder.
- **Open Recent** (File menu) lists your last 8 setups.
- **Restore Factory Defaults…** (File menu) returns routing, levels and monitor settings to the interface's power-on defaults. Every input is mixed at 0 dB, so turn your speakers down first.

## Menus

Everything in the window is also in the menu bar. On/off items show a ✓.

| Menu | Items |
|---|---|
| **File** | Open Setup… ⌘O · Open Recent ▸ · Save Setup ⌘S · Save Setup As… ⇧⌘S · Show Setups Folder · Save to Interface… · Restore Factory Defaults… |
| **View** | Show Monitor ⌥⌘1 · Show Mixer ⌥⌘2 · Show Routing ⌥⌘3 · Appearance ▸ · Reset Layout |
| **Monitor** | Dim ⌘D · Mute ⇧⌘M · Mute Left · Mute Right · Mono · −20 dB Pad |
| **Mixer** | Mix 1/2 ⌘1 · Mix 3/4 ⌘2 · Mix 5/6 ⌘3 · Mix 7/8 ⌘4 · Current Mix Is Stereo |
| **Routing** | Reset Input and DAW Names |
| **Device** | Sample Rate ▸ · Clock Source ▸ · Refresh from Device ⌘R |
| **Help** | Scarlett Gen 1 Mixer User Guide ⌘? · About |

## Layout

The window has three sections: **MONITOR**, **MIXER** and **ROUTING**. Everything scales to fit, so there's no scrolling.

- **Two sizes:** a fixed window, or **full screen** (green button, or View ▸ Enter Full Screen). The window can't be dragged to other sizes.
- **Click ▾** on a section's header to minimize it to a thin bar; click ▸ to expand it (or use View ▸ Show …). The app remembers this between launches.
- **View ▸ Reset Layout** expands every section again.

## Good to know

- **Only one app can control the interface at a time.** Quit other mixer software (and this app) before switching.
- **The app reads the full mixer once when it connects,** then keeps it in step with your changes. It keeps polling the meters, the knob and sync.
- **Settings live in the interface** until it's powered off, unless you use **Save to Interface…**.
- **Known issue:** after a power cycle the interface plays what you saved to it, but reports defaults, so the app shows defaults. Open your setup file to bring the app and interface back in step.
- **Clocking an ADAT expander:** run both at the same sample rate. Usually the 18i20 stays on INTERNAL and the expander follows it (expander clock source ADAT). At 88.2/96 kHz, ADAT carries 4 channels instead of 8.
