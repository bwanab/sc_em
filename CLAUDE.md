# sc_em Codebase Analysis

## Overview
sc_em is a modular synthesizer backend implementation using SuperCollider as the audio engine. It provides a framework for building and connecting synthesizer modules through JSON configuration files.

## Architecture

### Core Components

#### 1. SuperCollider Integration
- **OSC Communication**: All communication with SuperCollider is done via OSC (Open Sound Control)
- **Synth Definitions**: Located in `sc_defs/` directory containing SuperCollider synth definitions (.sc files)
- **Module Loading**: System reads and parses syndefs at runtime via `ScClient.load_synths/1`

#### 2. Node System
- **Node Structure**: Defined in `Modsynth.Node` struct with fields:
  - `name`: String identifier
  - `parameters`: List of parameter specifications
  - `bus_type`: `:audio` or `:control` 
  - `node_id`: Unique identifier within synth
  - `sc_id`: SuperCollider node ID
  - `val`: Optional parameter value
  - `control`: Control type (`:note`, `:gain`, etc.)

#### 3. Connection System
- **Connection Structure**: Defined in `Modsynth.Connection` struct
- **Node Parameters**: `Modsynth.Node_Param` links nodes by ID and parameter name
- **Bus Management**: Automatic audio/control bus allocation for connections

#### 4. JSON Configuration Format
Example structure from `fat-saw.json`:
```json
{
  "nodes": [
    {"id": 1, "name": "piano-in", "control": null, "val": null, "x": 0.0, "y": 0.0},
    {"id": 2, "name": "c-splitter", "control": null, "val": null, "x": 102.0, "y": 20.0}
  ],
  "connections": [
    {
      "from_node": {"id": 1, "name": "piano-in", "param_name": "freq"},
      "to_node": {"id": 2, "name": "c-splitter", "param_name": "in"}
    }
  ],
  "frame": {"width": 1007.0, "height": 600.0},
  "master_vol": 0.3
}
```

### Key Features

#### 1. Module Types
- **Input Modules**: `midi-in`, `piano-in`, `audio-in`
- **Processing Modules**: `saw-osc`, `moog-filt`, `amp`, `reverb`
- **Control Modules**: `const`, `slider-ctl`, `cc-in`, `cc-cont-in`
- **Output Modules**: `audio-out`
- **Utility Modules**: `c-splitter`, `pct-add`

#### 2. MIDI Integration
- **MIDI Input**: Handled by `midi_in` dependency
- **Note Control**: Automatic gate registration for note-based synths
- **CC Control**: Continuous controller mapping support
- **Device Selection**: Configurable MIDI device selection

#### 3. Build Order Management
- **Dependency Resolution**: `reorder_nodes/2` ensures proper SuperCollider build order
- **Audio-out First**: System builds from audio output backwards to inputs
- **Recursive Ordering**: Handles complex dependency chains

#### 4. External Control Setup
- **Control Detection**: `is_external_control/1` identifies controllable modules
- **MIDI Mapping**: Automatic MIDI CC and note mapping
- **Parameter Binding**: Direct parameter control via external sources

## File Structure

### Core Library (`lib/`)
- `modsynth.ex` - Main module with synth loading and connection logic
- `sc_client.ex` - SuperCollider communication interface
- `conversion_prims.ex` - Data conversion utilities
- `convert_circuits.ex` - Circuit conversion functions
- `read_synth_def.ex` - SuperCollider synth definition parser
- `message.ex` - Message handling
- `osc.ex` - OSC communication
- `serialize.ex` - Data serialization
- `supervisor.ex` - Application supervisor

### Examples (`examples/`)
30+ example synth configurations including:
- Basic synths: `fat-saw.json`, `saw-example.json`
- Effects: `reverb`, `echo`, `wah-wah`
- MIDI control: `midi-in.json`, `cc-in.json`
- Complex patches: `leslie.json`, `syn-on-own-4.json`

### Scripts (`scripts/`)
- `pachelbel.exs` - MIDI file playback example
- `pach_chords.exs` - Chord progression example

## Dependencies
- `jason` - JSON parsing
- `libgraph` - Graph data structure (for dependency resolution)
- `music_build` - Music composition utilities
- `midi_in` - MIDI input handling
- `dialyxir` - Static analysis

## GUI Considerations

### Current State
- JSON files must be edited manually
- No visual interface for synth creation/editing
- Coordinates in JSON suggest visual layout was planned (`x`, `y` fields)
- Frame dimensions indicate display canvas size

### GUI Approach Options

#### 1. Phoenix LiveView (Recommended)
**Pros:**
- Real-time updates perfect for interactive synth editing
- WebSocket-based communication for live parameter changes
- Rich HTML5 Canvas or SVG support for visual node editing
- Can leverage existing Elixir/Phoenix ecosystem
- Server-side state management fits well with SuperCollider backend
- Easy deployment and remote access

**Implementation approach:**
- Node/connection visual editor with drag-and-drop
- Real-time parameter controls
- Live audio visualization
- JSON import/export functionality
- Collaborative editing capabilities

#### 2. Scenic (Current Attempt)
**Pros:**
- Native Elixir GUI framework
- Direct integration with existing codebase
- Lower latency than web-based solutions
- Hardware-accelerated graphics

**Cons:**
- Limited ecosystem and documentation
- More complex UI development
- Platform-specific deployment challenges

#### 3. Web-based with Phoenix + JavaScript
**Pros:**
- Mature ecosystem (React, Vue, etc.)
- Rich canvas libraries (Fabric.js, Konva.js)
- Extensive UI component libraries
- Cross-platform compatibility

**Implementation Libraries:**
- React Flow or Vue Flow for node-based editing
- Tone.js for web audio integration
- Socket.io or Phoenix Channels for real-time communication

#### 4. Desktop Application
**Options:**
- Electron + web technologies
- Tauri + Rust/WebView
- Native desktop (Qt, GTK)

### Recommended GUI Architecture

**Phoenix LiveView Implementation:**
1. **Node Editor Component**: Visual drag-and-drop interface
2. **Parameter Panel**: Real-time control interface
3. **Connection Manager**: Visual cable patching
4. **Preset Manager**: Save/load synth configurations
5. **Live Preview**: Real-time audio parameter visualization
6. **JSON Bridge**: Import/export existing configurations

**Key Features to Implement:**
- Visual node positioning and connection
- Parameter knobs and sliders
- Real-time value updates
- Audio routing visualization
- Preset management
- MIDI learn functionality
- Collaborative editing

The frame dimensions and x/y coordinates in the JSON files suggest the original design already considered a visual interface, making GUI development a natural evolution of the project.

## GUI Implementation - Phoenix LiveView (COMPLETED)

### Project Structure
The GUI has been implemented as a separate Phoenix LiveView project (`modsynth_gui_phx`) that uses sc_em as a dependency, maintaining clean separation between the synthesizer engine and the user interface.

### Architecture Overview

#### Core Components Implemented

1. **File Management System** (`lib/modsynth_gui_phx/file_manager.ex`)
   - Manages `~/.modsynth/synth_networks` directory for user files
   - Environment variable support via `MODSYNTH_DIR`
   - JSON file read/write operations
   - Separation of user files and example files

2. **Synth Manager** (`lib/modsynth_gui_phx/synth_manager.ex`)
   - GenServer for sc_em backend integration
   - Handles synth loading, playing, and stopping
   - Manages state between GUI and SuperCollider
   - Proper error handling and logging

3. **LiveView Editor** (`lib/modsynth_gui_phx_web/live/synth_editor_live.ex`)
   - Main visual interface component
   - Real-time node positioning and connection updates
   - File browser integration
   - Hardware synth module-style node rendering

4. **JavaScript Integration** (`assets/js/synth_canvas.js`)
   - Drag-and-drop functionality for nodes
   - SVG canvas interaction
   - Real-time position updates to LiveView

### Visual Design Features

#### Hardware Synth Module Aesthetics
- **Color-coded node headers** by module type:
  - Pink: MIDI/Audio I/O (`midi-in`, `piano-in`, `audio-in`, `audio-out`)
  - Orange: Oscillators (`saw-osc`, `square-osc`, `sine-osc`)
  - Green: Filters (`moog-filt`, `lp-filt`, `hp-filt`)
  - Purple: Amplifiers/Envelopes (`amp`, `perc-env`, `release`)
  - Gray: Controls (`const`, `slider-ctl`, `cc-in`)
  - Blue: Effects (`reverb`, `echo`, `delay`)

- **Hardware aesthetic details**:
  - Rounded corners with shadows
  - Simulated screws in corners
  - LED indicators for selection state
  - Input/output jacks with realistic styling

#### Patch Cable System
- **Curved, realistic-looking connections**
- **Color-coded by signal type**:
  - Pink: MIDI signals
  - Orange: Audio signals  
  - Green: Processed audio
  - Gray: Control signals
  - Red: Default/unknown
- **Visual depth effects**: Shadow and highlight layers

#### Responsive Layout
- **Optimized for MacBook Air M1** (1200x800 canvas)
- **Flexible for larger monitors**
- **Dark theme** suitable for music production
- **Grid pattern background** for positioning reference

### Backend Integration

#### sc_em API Usage
Based on analysis of `../modsynth_gui2/lib/scenes/home.ex`, the correct integration pattern:

```elixir
# Load and validate synth configuration
{nodes, connections, dims} = Modsynth.look(filename)

# Play synth with MIDI device
Modsynth.play(filename, "AE-30")

# Stop synth
ScClient.group_free(1)
```

#### Data Flow
1. **Load**: GUI JSON → temp file → `Modsynth.look` → validation → SynthManager state
2. **Play**: SynthManager state → temp file → `Modsynth.play` → SuperCollider
3. **Stop**: `ScClient.group_free(1)` → SuperCollider
4. **Save**: GUI state → JSON → user directory

### File Structure

```
modsynth_gui_phx/
├── lib/
│   ├── modsynth_gui_phx/
│   │   ├── file_manager.ex           # File operations
│   │   ├── synth_manager.ex          # sc_em integration
│   │   └── application.ex            # Supervision tree
│   └── modsynth_gui_phx_web/
│       ├── live/
│       │   └── synth_editor_live.ex  # Main LiveView
│       └── router.ex                 # Route configuration
├── assets/
│   └── js/
│       ├── synth_canvas.js           # Drag-and-drop
│       └── app.js                    # Hook integration
└── mix.exs                           # Dependencies (includes sc_em)
```

### Key Features Implemented

1. **Visual Node Editor**
   - Drag-and-drop node positioning
   - Real-time connection updates
   - Hardware synth module styling
   - Selection highlighting

2. **File Management**
   - Load example files from `../sc_em/examples/`
   - Save/load user files from `~/.modsynth/synth_networks/`
   - File browser with categorized listings

3. **Synth Control**
   - Play/stop buttons with proper state management
   - Integration with AE-30 MIDI device
   - Error handling and user feedback

4. **Real-time Updates**
   - LiveView for instant UI updates
   - JavaScript hooks for smooth interactions
   - Proper state synchronization

### Usage Instructions

1. **Start the server**: `mix phx.server`
2. **Load a synth**: Click "Load File" and select from examples or user files
3. **Edit visually**: Drag nodes around, connections follow automatically
4. **Play/Stop**: Use the play/stop buttons to control the synth
5. **Save**: Enter a filename and save your modifications

### Future Enhancement Opportunities

1. **Connection Management**
   - Visual connection creation/deletion
   - Connection validation with warnings
   - Multiple input/output ports per node

2. **Parameter Controls**
   - Real-time parameter sliders/knobs
   - MIDI learn functionality
   - Parameter automation

3. **Node Management**
   - Add new nodes from available SynthDefs
   - Node deletion and duplication
   - Node library browser

4. **MIDI Integration**
   - MIDI file playback controls
   - External MIDI device selection
   - Real-time MIDI visualization

5. **Advanced Features**
   - Undo/redo functionality
   - Preset management system
   - Collaborative editing
   - Export to different formats

### Technical Notes

- **Canvas Dimensions**: 1200x800 optimized for MacBook Air M1
- **Node Dimensions**: 140x80 pixels with proper jack positioning
- **Connection Curves**: Bezier curves for realistic patch cable appearance
- **File Format**: Compatible with existing sc_em JSON structure
- **State Management**: GenServer-based backend state with LiveView frontend state
- **Error Handling**: Comprehensive try-catch blocks with user-friendly messages

This implementation provides a solid foundation for visual modular synthesizer editing while maintaining full compatibility with the existing sc_em backend system.