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
synthfile = args.synthfile

note = Note.new(:C, octave: 3, duration: 100)
stm = %{0 => STrack.new([note], name: "long_note", tpqn: 960, type: :instrument, program_number: 73, bpm: 100)}

port_name = "modsynth"
port = Midiex.create_virtual_output(port_name)
d = Modsynth.play(Path.expand(synthfile), port_name)
pid = MidiPlayer.play(stm, synth: port)
MidiPlayer.wait_play(pid)
ScClient.group_free(1)
Midiex.close(port)
