(
SynthDef(\pluck_bass, { |outbus, note = 42, amp = 0.5, gate=1|
  var freq = note.midicps;
  var subfreq = freq / 2;

  // Envelopes
  var subenv = Env.adsr(0.01, 0.3, amp/5, 1, amp).kr(2, gate);
  var env = Env.adsr(0.01, 0.5, amp/3, 1, amp).kr(2, gate);

  // Component synthesis
  var pluck = Pluck.ar(PinkNoise.ar, 1, 0.2, subfreq.reciprocal) * subenv * 2;
  var tri = VarSaw.ar(freq) * env;
  var sin = SinOsc.ar(freq) * env;
  var sub = (SinOsc.ar([subfreq, subfreq - 2, subfreq + 2]).sum * subenv).tanh;
  var click = RLPF.ar(Impulse.ar(0), [2000, 8000], 1, amp/10, -0.5).sum * 1000 * amp/10;

  // Initial signal
	var sig = pluck + tri + sub; // + click;

  // Resonant LPFs
  sig = RLPF.ar(sig, XLine.ar(freq * 100, freq * 10, 0.15));
  sig = sig + (MoogFF.ar(sig, freq * 20, 2.5) * 0.1);

  // EQ resulting signal
  sig = BPeakEQ.ar(sig, 400, 0.5, -9);
  sig = BPeakEQ.ar(sig, 2000, 0.5, 6);
  sig = BHiShelf.ar(sig, 8000, 1, 3);
  sig = BPeakEQ.ar(sig, 200, 1, 3);

  // Apply another envelope to dampen a bit more
  sig = sig * XLine.kr(1, 0.6, 0.1);

  // Tanh distortion / limiting
  sig = (sig * 1).tanh;

  // Another round of signal coloring, using another RLPF
  // and sine components
  sig = sig + RLPF.ar(sig, XLine.ar(freq * 100, freq * 10, 0.15)) + sin + sub;

  // Another round of tanh distortion / limiting
  sig = (sig / 2.3).tanh;

  // Another resonant LPF
  sig = MoogFF.ar(sig, XLine.ar(freq*150, freq*30, 0.1), 0.1);

  Out.ar(outbus, sig!2);
}).load;
)

s.dumpOSC(0)

x = Synth("pluck_bass", [\note, 31, \amp, 0.6])
x.set("gate", 0)
x.set("gate", 1)