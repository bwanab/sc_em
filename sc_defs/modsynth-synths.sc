(
~dir = "/home/bill/Dropbox/music/supercollider/synthdefs/modsynth/";

SynthDef("audio-out", {arg ib1 = 55, ib2 = 56;
	Out.ar(0, In.ar(ib1), In.ar(ib2));
}).writeDefFile(~dir);

SynthDef("audio-in", {arg ob = 55;
	Out.ar(ob, In.ar(0));
}).writeDefFile(~dir);

SynthDef("c-splitter", {arg ob1 = 65, ob2 = 66, ib = 55;
	Out.ar([ob1, ob2], In.ar(ib));
}).writeDefFile(~dir);

SynthDef("a-splitter", {arg ob1 = 65, ob2 = 66, ib = 55, pos = 0, lev = 0.1;
	Out.ar([ob1, ob2], Pan2(ib, pos, lev));
}).writeDefFile(~dir);

SynthDef("a-mixer-2", {arg ob = 65, ib1 = 55, ib2 = 56;
	Out.ar(ob, In.ar(ib1) + In.ar(ib2));
}).writeDefFile(~dir);

SynthDef("a-mixer-4", {arg ob = 65, ib1 = 55, ib2 = 56, ib3 = 57, ib4 = 58;
	Out.ar(ob, In.ar(ib1) + In.ar(ib2) + In.ar(ib3) + In.ar(ib4));
}).writeDefFile(~dir);

SynthDef("const", {arg val = 69, ob = 65;
	Out.kr(ob, val);
}).writeDefFile(~dir);

SynthDef("midi-in", {arg note = 69, ob = 65;
	Out.kr(ob, note);
}).writeDefFile(~dir);

SynthDef("cc-in", {arg ib = 55, ob = 65;
	Out.kr(ob, ib);
}).writeDefFile(~dir);

SynthDef("note-freq", {arg note = 55, ob = 65;
	Out.kr(ob, midicps(In.kr(note)));
}).writeDefFile(~dir);

SynthDef("amp", {arg ib = 55, ob = 65, gain = 0.1;
	Out.ar(ob, In.kr(gain) * In.ar(ib));
}).writeDefFile(~dir);

SynthDef("saw-osc", {arg ib = 55, ob = 65;
	Out.ar(ob, Saw.ar(In.kr(ib)));
}).writeDefFile(~dir);

SynthDef("s_sin-osc", {arg ib = 55, ob = 65;
	Out.ar(ob, SinOsc.ar(In.kr(ib)));
}).writeDefFile(~dir);

SynthDef("sin-vco", {arg ib = 55, ob = 65;
	Out.kr(ob, SinOsc.kr(In.kr(ib)));
}).writeDefFile(~dir);

SynthDef("rand-in", {arg ob = 65, lo = 0, hi = 0, trig = 0;
	var low = In.kr(lo);
	var high = In.kr(hi);
	var trigger = In.kr(trig);
	Out.ar(ob, TRand.ar(low, high, trigger));
}).writeDefFile(~dir);

SynthDef("square-osc", {arg ib = 55, ob = 65, width = 0.5;
	Out.ar(ob, Pulse.ar(In.ar(ib), 0.004 * In.kr(width)));
}).writeDefFile(~dir);

SynthDef("lp-filt", {arg ib = 55, ob = 65, cutoff = 11;
	Out.ar(ob, LPF.ar(In.ar(ib), In.kr(cutoff) * 3));
}).writeDefFile(~dir);

SynthDef("hp-filt", {arg ib = 55, ob = 65, cutoff = 300;
	Out.ar(ob, HPF.ar(In.ar(ib), In.kr(cutoff) * 40));
}).writeDefFile(~dir);

SynthDef("bp-filt", {arg ib = 55, ob = 65, freq = 300, q = 1;
	Out.ar(ob, BPF.ar(In.ar(ib), In.kr(freq), In.kr(q)));
}).writeDefFile(~dir);

SynthDef("moog-filt", {arg ib = 55, ob = 65, cutoff = 300, lpf_res = 1;
	Out.ar(ob, MoogFF.ar(In.ar(ib), In.kr(cutoff), In.kr(lpf_res)));
}).writeDefFile(~dir);

SynthDef("mult", {arg ib = 55, ob = 65, gain = 1;
	Out.ar(ob, In.ar(ib) * In.kr(gain));
}).writeDefFile(~dir);

SynthDef("pct-add", {arg ib = 55, ob = 65, gain = 1;
	Out.ar(ob, In.ar(ib) * In.kr(gain));
}).writeDefFile(~dir);

SynthDef("val-add", {arg ib = 55, ob = 65, val = 0;
	Out.ar(ob, In.ar(ib) + In.kr(val));
}).writeDefFile(~dir);

SynthDef("adsr-env", {arg ib = 55, ob = 65, a = 0.1, d = 0.2, s = 0.5, r = 1, gate = 1;
	Out.ar(ob, In.ar(ib) * Env.adsr(a, d, s, r).kr(2, gate));
}).writeDefFile(~dir);

SynthDef("perc-env", {arg ib = 55, ob = 65, a = 0.1,  r = 1, gate = 1;
	Out.ar(ob, In.ar(ib) * Env.perc(a, r).kr(2, gate));
}).writeDefFile(~dir);

SynthDef("freeverb", {arg ib = 55, ob = 65, wet_dry = 0.5,  room_size = 0.3, dampening = 0.3;
	Out.ar(ob, FreeVerb.ar(In.ar(ib), In.kr(wet_dry), In.kr(room_size), In.kr(dampening)));
}).writeDefFile(~dir);

SynthDef("echo", {arg ib = 55, ob = 65, delay_time = 1, decay_time = 1;
	Out.ar(ob, CombN.ar(In.ar(ib), 5, In.kr(delay_time), In.kr(decay_time)));
}).writeDefFile(~dir);

)

(
~gaintoaudio = Bus.audio();
~ctonote = Bus.control();
~ctogain = Bus.control();
~notetosaw = Bus.control();
~sawtogain = Bus.audio();
)

~gain = Synth("const", [\val, 0.3, \ob, ~ctogain]);
~note = Synth("const", [\val, 50, \ob, ~ctonote]);
Synth("note-freq", [\note, ~ctonote, \ob, ~notetosaw]);
Synth("saw-osc", [\ib, ~notetosaw, \ob, ~sawtogain]);
Synth("amp", [\ib, ~sawtogain, \gain, ~ctogain, \ob, ~gaintoaudio]);
Synth("audio-out", [\ib1, ~gaintoaudio, \ib2, ~gaintoaudio]);
~note.set("val", 40)
~gain.set("val", 0.4)
