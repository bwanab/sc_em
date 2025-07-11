Mix.install([
  {:sc_em, path: "."}
])
Mix.Task.run("loadconfig")

require Logger
Logger.configure(level: :info)

progression = [:I, :V, :vi, :iii, :IV, :I, :IV, :V]
chords = (Enum.map(progression, fn roman_numeral -> Chord.from_roman_numeral(roman_numeral, :C, octave: 4, duration: 4, inversion: 0, channel: 0) end)
         |> Enum.map(fn s -> Sonority.to_notes(s) end)
         |> Enum.zip()
         |> Enum.map(&Tuple.to_list/1)
         |> Enum.map(fn ss -> STrack.new(ss) end))
stm = Enum.zip(0..length(chords) - 1, chords) |> Map.new
