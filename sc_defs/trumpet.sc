(
////////////////////////////////////////////////////////////////
// EPIC SAX GUY SynthDefs
// http://www.youtube.com/watch?v=KHy7DGLTt8g
// Not yet there... but hearable

// sounds more like a trumpet/horn after the failure and cheesyness of the stk sax
SynthDef(\sax, { |out, freq=440, amp=0.1, gate=1|
	var num = 16;
	var harms = Array.series(num, 1, 1) * Array.exprand(num, 0.995, 1.001);
	var snd = SinOsc.ar(freq * SinOsc.kr(Rand(2.0,5.0),0,Rand(0.001, 0.01),1) * harms, mul:Array.geom(num, 1, 0.63));
	snd = Splay.ar(snd);
	snd = BBandPass.ar(snd, freq * XLine.kr(0.1,4,0.01), 2);
	snd = snd * amp * EnvGen.ar(Env.adsr(0.001, 0.2, 0.7, 0.2), gate, doneAction:2);
	Out.ar(out, snd!2);
}).add;

// should be more like a gated synth, but this one gives the rhythmic element
// remember to pass the bps from the language tempo!
SynthDef(\lead, { |out, freq=440, amp=0.1, gate=1, bps=2|
    var snd;
    var seq = Demand.kr(Impulse.kr(bps*4), 0, Dseq(freq*[1,3,2], inf)).lag(0.01);
    snd = LFSaw.ar(freq*{rrand(0.995, 1.005)}!4);
    snd = Splay.ar(snd);
    snd = MoogFF.ar(snd, seq, 0.5);
    snd = snd * EnvGen.ar(Env.asr(0.01,1,0.01), gate, doneAction:2);
    OffsetOut.ar(out, snd * amp);
}).add;

// yep, an organ with a sub bass tone :D
SynthDef(\organ, { |out, freq=440, amp=0.1, gate=1|
    var snd;
    snd = Splay.ar(SinOsc.ar(freq*Array.geom(4,1,2), mul:1/4));
    snd = snd + SinOsc.ar(freq/2, mul:0.4)!2;
    snd = snd * EnvGen.ar(Env.asr(0.001,1,0.01), gate, doneAction:2);
    OffsetOut.ar(out, snd * amp);
}).add;

// from the synth def pool
SynthDef(\kick, { |out=0, amp=0.1, pan=0|
	var env0, env1, env1m, son;

	env0 =  EnvGen.ar(Env.new([0.5, 1, 0.5, 0], [0.005, 0.06, 0.26], [-4, -2, -4]), doneAction:2);
	env1 = EnvGen.ar(Env.new([110, 59, 29], [0.005, 0.29], [-4, -5]));
	env1m = env1.midicps;

	son = LFPulse.ar(env1m, 0, 0.5, 1, -0.5);
	son = son + WhiteNoise.ar(1);
	son = LPF.ar(son, env1m*1.5, env0);
	son = son + SinOsc.ar(env1m, 0.5, env0);

	son = son * 1.2;
	son = son.clip2(1);

	OffsetOut.ar(out, Pan2.ar(son * amp));
}).add;

// full of fail:

//SynthDef(\sax, { |out, freq=440, amp=0.1, gate=1|
//	var r_stiff = 67;
//	var r_ap = 63;
//	var noise = 10;
//	var pos = 20;
//	var vibf = 20;
//	var vibg = 1;
//	var press = 85;
//	var snd = StkSaxofony.ar(freq, r_stiff, r_ap, noise, pos, vibf, vibg, press, 1, amp);
//	snd = snd * EnvGen.ar(Env.adsr(0.001, 0.2, 0.7, 0.2), gate, doneAction:2);
//	Out.ar(out, snd!2);
//}).add;


)

////////////////////////////////////////////////////////////////
// EPIC SAX GUY TUNE
// http://www.youtube.com/watch?v=KHy7DGLTt8g
// ... still needs a nice gated pad

(
TempoClock.default.tempo = 2.1;

Pdef(\kick).quant = 4;
Pdef(\organ).quant = 4;
Pdef(\sax).quant = 4;
Pdef(\lead).quant = 4;

////////////////////////////////////////////////////////////////
Pdef(\kick, Pbind(\instrument, \kick, \dur, 1, \amp, 1)).play;

Pdef(\organ, Pbind(
	\instrument, \organ,
	\octave, [3,4],
	\root, 3,
	\scale, Scale.minor,
	\degree, Pstutter(3, Pseq([0,-2,2,4], inf)),
	\amp, 0.3,
	\dur, Pseq([1.5,1.5,1], inf)
)).play;

Pdef(\lead, Pbind(
	\instrument, \lead,
	\octave, [5,6],
	\root, 3,
	\scale, Scale.minor,
	\degree, Pseq([0,2,0,4], inf),
	\amp, 0.2,
	\bps, TempoClock.default.tempo,
	\dur, 4
)).play;

// needs more articulation...
Pdef(\sax, Pbind(
	\instrument, \sax,
	\root, 3,
	\scale, Scale.minor,
	\octave, 5,
	\legato, 0.75,
	\amp, Pwhite(0.9,1.0, inf),
	\degree, Pseq([Pseq([Pn(4,4),3,4],2), Pseq([4,6,4,3,2,0,0,1,2,0])], inf),
	\dur, Pseq([Pseq([2,1/2,Pn(1/4,3),3/4],2), Pseq([1.5,1,1,1,1,Pn(0.5,5)])], inf)
)).play;
)
