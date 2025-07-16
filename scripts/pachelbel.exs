Mix.install([
  {:sc_em, path: "."}
])
Mix.Task.run("loadconfig")

defmodule ArgsConfig do
  defstruct synthfile: "examples/fat-saw3.json", repeats: 3

  def from_args(args) do
    {opts, _args, _invalid} = OptionParser.parse(args,
      strict: [synthfile: :string, repeats: :integer]
    )

    struct(__MODULE__, opts)
  end
end

require Logger
Logger.configure(level: :info)

args = ArgsConfig.from_args(System.argv())
repeats = args.repeats
synthfile = args.synthfile


chords = MusicBuild.Examples.ArpeggioProgressions.build_chords([:I, :V, :vi, :iii, :IV, :I, :IV, :V], :C, 3, 1, 0)
patterns = [
  [4,1,2,3],
  [1,2,4,3],
  [2,3,4,2],
  [1,4,3,1],
  [1,2,3,4],
  [1,4,3,1],
  [1,2,3,2],
  [2,3,4,1]
]
arpeggios = (Enum.map(Enum.zip(chords, patterns), fn {c, p} -> Arpeggio.new(c, p, 0.5, 0) end)
            |> List.duplicate(repeats)
            |> List.flatten)
stm = %{0 => STrack.new(arpeggios, name: "arpeggios", tpqn: 960, type: :instrument, program_number: 73, bpm: 100)}

port_name = "modsynth"
port = Midiex.create_virtual_output(port_name)
Modsynth.play(Path.expand(synthfile), port_name)
pid = MidiPlayer.play(stm, synth: port)
MidiPlayer.wait_play(pid)
ScClient.group_free(1)
Midiex.close(port)
