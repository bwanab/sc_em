# sc_em 

This is a back end implementation of a modular synth using supercollider as the back end. All communication to supercollider is done using the OSC module included. The basic flow is as follows:

1. Small syndefs in supercollider form the core. Each of these syndefs have from 0 to several inputs, and 0 to several outputs. An example of 0 input is midi-in which simply listens for midi note events. An example of 0 output is audio-out which plays its input to the system audio. Other than that there are syndefs for reverb, cc messages, verious filter and oscillators. No editor for these synths is anticipated since supercollider provides a good environment for building them.

2. At runtime, the list of syndefs is read and parse to create nodes that are connected into networks that build a musical modular synth. For example, the simplist possible synth might be midi-in -> midi-freq -> synosc -> audio out, but they are generally more complex.

3. These synth networks are specified by json files that can reside anywhere, but there is an examples directory with several example synths. At present the only way to create or edit these files is by hand using a text editor.

4. The project supports playing the synths using an external midi device using Modsynth.play. In addition, also using Modsynth.play one can play a one track single note midi file. An example script doing this is provided as pachelbel.exs in the scripts directory.
