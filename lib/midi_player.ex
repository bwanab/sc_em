defmodule MidiPlayer do
  import ScClient
  require Logger

  def play(name) do
    load_synths()
    Process.sleep(2)
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
    bin_name = String.replace_suffix(name, ".mid", ".json")
    if File.exists?(bin_name) do
      {:ok, d} = File.read(bin_name)
      Serialize.decode(d)
    else
      midi = ReadMidiFile.read_file(name)
      {:ok, file} = File.open(bin_name, [:write])
      :ok = IO.binwrite(file, Serialize.encode(midi))
      File.close(file)
      midi
    end
  end

  def play_type0(midi) do
    track = midi.midi_tracks |> Enum.at(0)
    messages = track.midi_messages
    process_messages([messages], initial_state(midi))
  end

  @doc """
  In type 1 files, the first track contains the timing data for all the tracks.
  """
  def play_type1(midi) do
    [track1 | tracks] = midi.midi_tracks
    state = message_worker(track1.midi_messages, initial_state(midi))
    # message_worker(List.first(tracks).midi_messages, state) # for testing
    Enum.map(tracks, fn x -> x.midi_messages end) |>
      process_messages(state)
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

  def test_notes(n, delta) do
    midi = %{:ticks_per_quarter_note => 120}
    Enum.reduce(1..n, [], fn _x, acc -> acc ++
        [{:noteon, %{:channel => 2, :delta => delta, :note => 30, :vel => 127}},
         {:noteoff, %{:channel => 2, :delta => delta, :note => 30, :vel => 127}}]
    end) ++ [{:end_of_track, %{}}] |> message_worker(initial_state(midi))
    0
  end

  def message_worker([{type, _val} | _rest], state) when type == :end_of_track do state end
  def message_worker([{type, val} | rest], state) do
    delta = val.delta
    channel_set = MapSet.new([2])
    Logger.info("#{type} #{inspect(val)}")
    s = case type do
          :program_change ->
            wait(delta, state)
            synth = MidiMap.inst(val.program)
            state_synth = %{state.synth | val.channel => synth}
            %{state | :synth => state_synth}
          :tempo ->
            tickdiv = (val.val / 1000000) / state.tpqn
            %{state | :tickdiv => tickdiv}
          :noteon ->
            wait(delta, state)
            if MapSet.member?(channel_set, val.channel) do
              id = midi_sound(state.synth[val.channel], val.note, val.vel / 256)
              if state.notes[val.note] != 0 do
                Logger.warn("Note #{val.note} on without a prior note off")
              end
              %{state.notes | val.note => id}
            end
            state
          :noteoff ->
            wait(delta, state)
            if MapSet.member?(channel_set, val.channel) do
              set_control(state.notes[val.note], "gate", 0)
              %{state.notes | val.note => 0}
            end
            state
          :cc_event ->
            wait(delta, state)
            state
          _ ->
            wait(delta, state)
            state
        end
    message_worker(rest, s)
   end

  def wait(delta, state) do
    if delta > 0 do
      ms_to_sleep = round(delta * state.tickdiv * 1000)
      Logger.info("delta = #{delta} state.tickdiv = #{state.tickdiv} ms_to_sleep = #{ms_to_sleep}")
      Process.sleep(ms_to_sleep)
    end
  end
end
