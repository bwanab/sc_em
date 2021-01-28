defmodule MidiPlayer do
  import ReadMidiFile
  import ScClient
  require Logger

  def play(name) do
    load_synths()
    midi = read_file(name)
    case midi.midi_format do
      0 -> play_type0(midi)
      1 -> play_type1(midi)
      2 -> play_type2(midi)
    end
  end

  @doc """
  Midi files are slow to read. What this function is doing is to look at
  the suffix of the given name. If it is mid, it checks for the same file
  with suffix bin. If that exists, it reads it instead. If it doesn't, it
  reads the midi file, then writes the bin file into the same directory
  from which it will read the next time.
  """
  def read_file(name) do
    bin_name = String.replace_suffix(name, ".mid", ".bin")
    if File.exists?(bin_name) do
      {:ok, d} = File.read(bin_name)
      :erlang.binary_to_term(d)
    else
      midi = readFile(name)
      {:ok, file} = File.open(bin_name, [:write])
      IO.binwrite(file, :erlang.term_to_binary(midi))
      File.close(file)
      midi
    end
  end

  def play_type0(midi) do
    track = midi.midi_tracks |> Enum.at(0)
    messages = track.midi_messages
    process_messages([messages], initial_state(midi))
  end

  def play_type1(midi) do
    track = midi.midi_tracks |> Enum.at(0)
    messages = track.midi_messages
    message_worker(messages, initial_state(midi))
  end

  def play_type2(_midi) do
    throw("Don't know how to play type 2")
  end

  def initial_state(midi) do
    %{:tickdiv => 0.003,
      :tpqn => midi.ticks_per_quarter_note,
      :notes => Map.new(0..127, fn x -> {x, 0} end),
      :synth => Map.new(0..16, fn x -> {x, "miditest1"} end)}
  end

  def process_messages(list_of_message_lists, state) do
    stream = Task.async_stream(list_of_message_lists,
      fn ml -> message_worker(ml,  state) end,
      [{:timeout, :infinity}])
    Stream.run(stream)
  end

  def message_worker([{type, _val} | _rest], state) when type == :end_of_track do state end
  def message_worker([{type, val} | rest], state) do
    delta = val.delta
    channel_set = MapSet.new(1..7)
    s = case type do
          :program_change ->
            synth = MidiMap.inst(val.program)
            Logger.info("channel = #{val.channel} synth = #{synth}")
            state_synth = %{state.synth | val.channel => synth}
            %{state | :synth => state_synth}
          :tempo ->
            tickdiv = (val.val / 1000000) / state.tpqn
            Logger.debug("set tempo tickdiv = #{tickdiv}" )
            %{state | :tickdiv => tickdiv}
          :noteon ->
            if MapSet.member?(channel_set, val.channel) do
              wait(delta, state)
              Logger.info("#{type} #{inspect(val)} synth = #{state.synth[val.channel]}")
              id = midi_sound(state.synth[val.channel], val.note, val.vel / 256)
              %{state.notes | val.note => id}
              state
            else
              state
            end
          :noteoff ->
            if MapSet.member?(channel_set, val.channel) do
              wait(delta, state)
              Logger.info("#{type} #{inspect(val)}")
              set_control(state.notes[val.note], "gate", 0)
            end
            state
          :cc_event ->
            wait(delta, state)
            state
          _ ->
            Logger.info("#{type} #{inspect(val)} **********")
            state
        end
    message_worker(rest, s)
  end

  def wait(delta, state) do
    Logger.info("delta = #{delta} state.tickdiv = #{state.tickdiv}")
    if delta > 0 do
      ms_to_sleep = round(delta * state.tickdiv * 1000)
      Process.sleep(ms_to_sleep)
    end
  end
end
