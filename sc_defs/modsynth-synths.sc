(
~dir = "~/src/sc_em/synthdefs/".standardizePath;

SynthDef("audio-out", {arg b1 = 0, b2 = 0;
	Out.ar(0, In.ar([b1, b2]));
}).writeDefFile(~dir);

SynthDef("audio-in", {arg out_audio = 55;
	Out.ar(out_audio, In.ar(0));
}).writeDefFile(~dir);

SynthDef("c-splitter", {arg out_1 = 65, out_2 = 66, in = 55;
	var sig = In.kr(in);
	Out.kr(out_1, sig);
	Out.kr(out_2, sig);
}).writeDefFile(~dir);

// SynthDef("a-splitter", {arg ob1 = 65, ob2 = 66, in = 55, pos = 0, lev = 0.1;
// 	Out.ar([ob1, ob2], Pan2.ar(In.ar(in), In.kr(pos), In.kr(lev)));
// }).writeDefFile(~dir)

SynthDef("a-splitter", {arg out_1 = 65, out_2 = 66, in = 55, pos = 0, lev = 1;
	var sig = In.ar(in) * In.kr(lev);
	var v1 = (1 - In.kr(pos)) / 2;
	var v2 = 1 - v1;
	Out.ar(out_1, sig * v1.sqrt);
	Out.ar(out_2, sig * v2.sqrt);
}).writeDefFile(~dir);


SynthDef("a-mixer-2", {arg out_audio = 65, in1 = 55, in2 = 56;
	Out.ar(out_audio, In.ar(in1) + In.ar(in2));
}).writeDefFile(~dir);

SynthDef("a-mixer-4", {arg out_audio = 65, in1 = 55, in2 = 56, in3 = 57, in4 = 58;
	Out.ar(out_audio, In.ar(in1) + In.ar(in2) + In.ar(in3) + In.ar(in4));
}).writeDefFile(~dir);

SynthDef("const", {arg in = 0, out_val = 0;
	Out.kr(out_val, in);
}).writeDefFile(~dir);

// midi-in puts out a frequency, midi-in-note puts out the midi note
SynthDef("midi-in", {arg note = 69, out_freq = 65;
	Out.kr(out_freq, midicps(note));
}).writeDefFile(~dir);

SynthDef("midi-in-note", {arg note = 69, out_note = 65;
	Out.kr(out_note, note);
}).writeDefFile(~dir);

SynthDef("cc-in", {arg in = 0, out_val = 0;
	Out.kr(out_val, in);
}).writeDefFile(~dir);

SynthDef("note-freq", {arg note = 55, out_freq = 65;
	Out.kr(out_freq, midicps(In.kr(note)));
}).writeDefFile(~dir);

SynthDef("amp", {arg in = 0, out_audio = 0, gain = 0.0;
	Out.ar(out_audio, In.kr(gain) * In.ar(in));
}).writeDefFile(~dir);

SynthDef("saw-osc", {arg freq = 55, out_audio = 65;
	Out.ar(out_audio, Saw.ar(In.kr(freq)));
}).writeDefFile(~dir);

SynthDef("s_sin-osc", {arg freq = 55, out_audio = 65;
	Out.ar(out_audio, SinOsc.ar(In.kr(freq)));
}).writeDefFile(~dir);

SynthDef("sin-vco", {arg freq = 55, out_control = 65;
	Out.kr(out_control, SinOsc.kr(In.kr(freq)));
}).writeDefFile(~dir);

// SynthDef("flute", {arg freq = 55, sig = 65;
// 	var fr = In.kr(freq);
// 	var n = 12;
// 	var cutoff_freq1 = 300;
// 	var wave = Mix.fill(n,{|i|
// 		var mult;
// 		var div = 0.5;
// 		case
// 		{i == 1} {div = 1}
// 		{and(i == 3, fr >= cutoff_freq1)} {div = 0.5}
// 		{and(i == 3, fr < cutoff_freq1)} {div = 0.2}
// 		{and(i == 4, fr >= cutoff_freq1)} {div = 0.1}
// 		{and(i == 4, fr < cutoff_freq1)} {div = 0.4}
// 		{i > 4} {div = 0.02};
//
// 		mult= ((-1)**i)*(div/((i+1)));
// 		SinOsc.ar(fr*(i+1))*mult
// 	});
// 	Out.ar(sig, Mix.ar(wave/n));
// }).writeDefFile(~dir);

SynthDef("rand-in", {arg out_val = 65, lo = 0, hi = 0, trig = 0;
	var low = In.kr(lo);
	var high = In.kr(hi);
	var trigger = In.kr(trig);
	Out.ar(out_val, TRand.ar(low, high, trigger));
}).writeDefFile(~dir);

SynthDef("square-osc", {arg freq = 55, out_audio = 56, width = 0.5;
	var w = In.kr(width) / 2 + 0.5;
	Out.ar(out_audio, Pulse.ar(In.kr(freq),  * w));
}).writeDefFile(~dir);


SynthDef("blip-tone", {
	arg freq=40, nharm=12, detune=0.2, out_audio1=65, out_audio2=66;
	var sig;
	sig = Blip.ar(
		In.kr(freq) * LFNoise1.kr(0.2!16).bipolar(In.kr(detune)).midiratio,
		In.kr(nharm)
	);
	sig = sig * LFNoise1.kr(0.5!16).exprange(0.1,1);
	sig = Splay.ar(sig);
	//sig = Mix.ar(sig);
	Out.ar([out_audio1, out_audio2], sig);
}).writeDefFile(~dir);

SynthDef("lp-filt", {arg in = 55, out_audio = 65, cutoff = 11;
	Out.ar(out_audio, LPF.ar(In.ar(in), In.kr(cutoff)));
}).writeDefFile(~dir);

SynthDef("hp-filt", {arg in = 55, out_audio = 65, cutoff = 300;
	Out.ar(out_audio, HPF.ar(In.ar(in), In.kr(cutoff) * 40));
}).writeDefFile(~dir);

SynthDef("bp-filt", {arg in = 55, out_audio = 65, freq = 300, q = 1;
	Out.ar(out_audio, BPF.ar(In.ar(in), In.kr(freq), In.kr(q)));
}).writeDefFile(~dir);

SynthDef("moog-filt", {arg in = 55, out_audio = 65, cutoff = 300, lpf_res = 1;
	Out.ar(out_audio, MoogFF.ar(In.ar(in), In.kr(cutoff), In.kr(lpf_res), 0, 2));
}).writeDefFile(~dir);

SynthDef("c-scale", {arg in = 55, out_control = 65, lo = 10, hi = 100;
	Out.kr(out_control, In.kr(in).linlin(-1, 1, In.kr(lo), In.kr(hi)));
}).writeDefFile(~dir);

SynthDef("mult", {arg in = 55, out_audio = 65, gain = 1;
	Out.ar(out_audio, In.ar(in) * In.kr(gain));
}).writeDefFile(~dir);

SynthDef("pct-add", {arg in = 55, out_control = 65, gain = 1;
	Out.kr(out_control, In.kr(in) + (In.kr(in) * In.kr(gain)));
}).writeDefFile(~dir);

SynthDef("val-add", {arg in = 55, out_control = 65, val = 0;
	Out.kr(out_control, In.kr(in) + In.kr(val));
}).writeDefFile(~dir);

SynthDef("adsr-env", {arg in = 55, out_audio = 65, attack = 0.1, decay = 0.2, sustain = 0.1, release = 1, gate = 1;
	Out.ar(out_audio, In.ar(in) * Env.adsr(In.kr(attack), In.kr(decay), In.kr(sustain), In.kr(release)).kr(2, gate));
}).writeDefFile(~dir);

SynthDef("perc-env", {arg in = 55, out_audio = 65, attack = 0.1,  release = 1, gate = 1;
	Out.ar(out_audio, In.ar(in) * Env.perc(attack, release).kr(2, gate));
}).writeDefFile(~dir);

SynthDef("freeverb", {arg in = 55, out_audio = 65, wet_dry = 0.5,  room_size = 0.3, dampening = 0.3;
	Out.ar(out_audio, FreeVerb.ar(In.ar(in), In.kr(wet_dry), In.kr(room_size), In.kr(dampening)));
}).writeDefFile(~dir);

SynthDef("echo", {arg in = 55, out_audio = 65, delay_time = 1, decay_time = 1;
	var sig = In.ar(in);
	Out.ar(out_audio, (sig + CombL.ar(sig, 3, In.kr(delay_time), In.kr(decay_time))) / 2);
}).writeDefFile(~dir);

// SynthDef("a-level", {arg in = 55, out_control = 65;
// 	Out.kr(out_control, RunningMax.ar(In.ar(in), Impulse.ar(0.4)));
// }).writeDefFile(~dir);
)

(
~gaintoecho = Bus.audio();
~echotoaudio = Bus.audio();
~ctonote = Bus.control();
~ctogain = Bus.control();
~notetosaw = Bus.control();
~sawtoadsr = Bus.audio();≥
~adsrtogain = Bus.audio();


~gain = Synth("cc-in", [\in, 0.2, \out_val, ~ctogain]);
~note = Synth("cc-in", [\in, 50, \out_val, ~ctonote]);
Synth("audio-out", [\b1, ~echotoaudio, \b2, ~echotoaudio]);
Synth("freeverb", [\in, ~gaintoecho, \out_audio, ~echotoaudio]);
Synth("amp", [\in, ~adsrtogain, \gain, ~ctogain, \out_audio, ~gaintoecho]);
~adsr = Synth("adsr-env", [\in, ~sawtoadsr, \out_audio, ~adsrtogain]);
Synth("saw-osc", [\freq, ~notetosaw, \out_audio, ~sawtoadsr]);
Synth("note-freq", [\note, ~ctonote, \out_freq, ~notetosaw]);
)

~adsr = Synth("adsr-env", [\in, ~sawtoadsr, \out_audio, ~adsrtogain]);

~note.set("in", 53)
~gain.set("in", 0.3)
~adsr.set("gate", 0)

~echotoaudio.plot;
~sawtoadsr.plot;
~adsrtogain.plot;

{RunningMax.kr(In.ar(~gaintoecho),  Impulse.ar(0.4))}.plot;

Synth("saw-osc", [\freq, 110]);
