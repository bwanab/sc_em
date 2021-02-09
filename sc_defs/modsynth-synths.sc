(
~dir = "/home/bill/Dropbox/music/supercollider/synthdefs/modsynth/";

SynthDef("audio-out", {arg b1 = 55, b2 = 56;
	Out.ar(0, In.ar(b1), In.ar(b2));
}).writeDefFile(~dir);

SynthDef("audio-in", {arg out = 55;
	Out.ar(out, In.ar(0));
}).writeDefFile(~dir);

SynthDef("c-splitter", {arg ob1 = 65, ob2 = 66, in = 55;
	Out.kr([ob1, ob2], In.ar(in));
}).writeDefFile(~dir);

SynthDef("a-splitter", {arg ob1 = 65, ob2 = 66, in = 55, pos = 0, lev = 0.1;
	Out.ar([ob1, ob2], Pan2.ar(In.ar(in), pos, lev));
}).writeDefFile(~dir);

SynthDef("a-mixer-2", {arg out = 65, in1 = 55, in2 = 56;
	Out.ar(out, In.ar(in1) + In.ar(in2));
}).writeDefFile(~dir);

SynthDef("a-mixer-4", {arg out = 65, in1 = 55, in2 = 56, in3 = 57, in4 = 58;
	Out.ar(out, In.ar(in1) + In.ar(in2) + In.ar(in3) + In.ar(in4));
}).writeDefFile(~dir);

SynthDef("const", {arg in = 69, val = 65;
	Out.kr(val, in);
}).writeDefFile(~dir);

// midi-in puts out a frequency, midi-in-note puts out the midi note
SynthDef("midi-in", {arg note = 69, freq = 65;
	Out.kr(freq, midicps(note));
}).writeDefFile(~dir);

SynthDef("midi-in-note", {arg note = 69, out = 65;
	Out.kr(out, note);
}).writeDefFile(~dir);

SynthDef("cc-in", {arg in = 55, val = 65;
	Out.kr(val, in);
}).writeDefFile(~dir);

SynthDef("note-freq", {arg note = 55, freq = 65;
	Out.kr(freq, midicps(In.kr(note)));
}).writeDefFile(~dir);

SynthDef("amp", {arg in = 55, out = 65, gain = 0.1;
	Out.ar(out, In.kr(gain) * In.ar(in));
}).writeDefFile(~dir);

SynthDef("saw-osc", {arg freq = 55, sig = 65;
	Out.ar(sig, Saw.ar(In.kr(freq)));
}).writeDefFile(~dir);

SynthDef("s_sin-osc", {arg freq = 55, sig = 65;
	Out.ar(sig, SinOsc.ar(In.kr(freq)));
}).writeDefFile(~dir);

SynthDef("sin-vco", {arg freq = 55, out = 65;
	Out.kr(out, SinOsc.kr(In.kr(freq)));
}).writeDefFile(~dir);

SynthDef("rand-in", {arg out = 65, lo = 0, hi = 0, trig = 0;
	var low = In.kr(lo);
	var high = In.kr(hi);
	var trigger = In.kr(trig);
	Out.ar(out, TRand.ar(low, high, trigger));
}).writeDefFile(~dir);

SynthDef("square-osc", {arg freq = 55, sig = 56, width = 0.5;
	Out.ar(sig, Pulse.ar(In.ar(freq), 0.004 * In.kr(width)));
}).writeDefFile(~dir);

SynthDef("lp-filt", {arg in = 55, out = 65, cutoff = 11;
	Out.ar(out, LPF.ar(In.ar(in), In.kr(cutoff) * 3));
}).writeDefFile(~dir);

SynthDef("hp-filt", {arg in = 55, out = 65, cutoff = 300;
	Out.ar(out, HPF.ar(In.ar(in), In.kr(cutoff) * 40));
}).writeDefFile(~dir);

SynthDef("bp-filt", {arg in = 55, out = 65, freq = 300, q = 1;
	Out.ar(out, BPF.ar(In.ar(in), In.kr(freq), In.kr(q)));
}).writeDefFile(~dir);

SynthDef("moog-filt", {arg in = 55, out = 65, cutoff = 300, lpf_res = 1;
	Out.ar(out, MoogFF.ar(In.ar(in), In.kr(cutoff), In.kr(lpf_res)));
}).writeDefFile(~dir);

SynthDef("mult", {arg in = 55, out = 65, gain = 1;
	Out.ar(out, In.ar(in) * In.kr(gain));
}).writeDefFile(~dir);

SynthDef("pct-add", {arg in = 55, out = 65, gain = 1;
	Out.ar(out, In.ar(in) * In.kr(gain));
}).writeDefFile(~dir);

SynthDef("val-add", {arg in = 55, out = 65, val = 0;
	Out.ar(out, In.ar(in) + In.kr(val));
}).writeDefFile(~dir);

SynthDef("adsr-env", {arg in = 55, out = 65, attack = 0.1, decay = 0.2, sustain = 0.5, release = 1, gate = 1;
	Out.ar(out, In.ar(in) * Env.adsr(attack, decay, sustain, release).kr(2, gate));
}).writeDefFile(~dir);

SynthDef("perc-env", {arg in = 55, out = 65, attack = 0.1,  release = 1, gate = 1;
	Out.ar(out, In.ar(in) * Env.perc(attack, release).kr(2, gate));
}).writeDefFile(~dir);

SynthDef("freeverb", {arg in = 55, out = 65, wet_dry = 0.5,  room_size = 0.3, dampening = 0.3;
	Out.ar(out, FreeVerb.ar(In.ar(in), In.kr(wet_dry), In.kr(room_size), In.kr(dampening)));
}).writeDefFile(~dir);

SynthDef("echo", {arg in = 55, out = 65, delay_time = 1, decay_time = 1;
	Out.ar(out, CombN.ar(In.ar(in), 5, In.kr(delay_time), In.kr(decay_time)));
}).writeDefFile(~dir);

)


(
~gaintoaudio = Bus.audio();
~ctonote = Bus.control();
~ctogain = Bus.control();
~notetosaw = Bus.control();
~sawtogain = Bus.audio();
)

~gain = Synth("const", [\val, 0.3, \val, ~ctogain]);
~note = Synth("const", [\val, 50, \ob, ~ctonote]);
Synth("note-freq", [\note, ~ctonote, \ob, ~notetosaw]);
Synth("saw-osc", [\ib, ~notetosaw, \ob, ~sawtogain]);
Synth("amp", [\ib, ~sawtogain, \gain, ~ctogain, \ob, ~gaintoaudio]);
Synth("audio-out", [\ib1, ~gaintoaudio, \ib2, ~gaintoaudio]);
~note.set("val", 40)
~gain.set("val", 0.4)
