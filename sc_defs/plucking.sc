(
SynthDef("plucking", {arg amp = 0.1, freq = 220, decay = 5, coef = 0.1;
var env, snd;
env = EnvGen.kr(Env.linen(0, decay, 0.5), doneAction: 2);
snd = Pluck.ar(
		in: SinOsc.ar(0.5*freq, 0, amp),
        trig: Impulse.kr(0),

        maxdelaytime: 0.1,
        delaytime: freq.reciprocal,
        decaytime: decay,
        coef: coef);
    Out.ar(0, [snd, snd]);
}).add;
)
(
SynthDef(\FreeVerb2x2, {|outbus, mix = 0.23, room = 0.42, damp = 0.666, amp = 1.0|
    var signal;

    signal = In.ar(outbus, 2);

    ReplaceOut.ar(outbus,
        FreeVerb2.ar( // FreeVerb2 - true stereo UGen
            signal[0], // Left channel
            signal[1], // Right Channel
            mix, room, damp, amp)); // same params as FreeVerb 1 chn version

}).add;
z = Synth(\FreeVerb2x2, [\outbus, 0], addAction:\addToTail)
)
(
Pbind(
    \instrument, "plucking",
    \scale, Scale.locrian,
	\degree, Prand([[-2.5, -4.001], [-7.002, -5], [-1, -3.003], [-1.005, -0.51], [-5, -3], [-4, -4], [0, 1]], inf),
	\amp, Pseq([0.23, 0.042, 0.2, 0.32], inf),
	\decay, Pseq([0.25,2.5, 0.025, 0.25], inf),
	\coef, Pseq([0.3, 0.2, 0.9], inf),
	\dur, Pseq([0.2, 0.01, 0.21, 0.001, 0.0001, 0.00911, 0.191, 0.23],inf)
).play;
)
