defmodule MidiPlayer do
  import ReadMidiFile
  import ScClient
  require Logger

  def play(name) do
    load_synths()
    midi = readFile(name)
    case midi.midi_format do
      0 -> play_type0(midi)
      1 -> play_type1(midi)
      2 -> play_type2(midi)
    end
  end

  def play_type0(midi) do
    track = midi.midi_tracks |> Enum.at(0)
    messages = track.midi_messages
    process_messages([messages], midi)
  end

  def play_type1(_midi) do
    throw("Don't know how to play type 1")
  end

  def play_type2(_midi) do
    throw("Don't know how to play type 2")
  end

  def process_messages(list_of_message_lists, midi) do
    stream = Task.async_stream(list_of_message_lists,
      fn ml -> message_worker(ml,  %{:tickdiv => 0.003,
                                     :tpqn => midi.ticks_per_quarter_note,
                                     :notes => Map.new(0..127, fn x -> {x, 0} end)}) end,
      [{:timeout, :infinity}])
    Stream.run(stream)
  end

  def message_worker([{type, _val} | _rest], _state) when type == :end_of_track do [] end
  def message_worker([{type, val} | rest], state) do
    delta = val.delta
    if delta > 0 do
      ms_to_sleep = round(delta * state.tickdiv * 1000)
      # Logger.info("ms_to_sleep = #{ms_to_sleep}")
      Process.sleep(ms_to_sleep)
    end
    s = case type do
          :tempo ->
            tickdiv = (val.val / 1000000) / state.tpqn
            Logger.info("set tempo tickdiv = #{tickdiv}" )
            %{state | :tickdiv => tickdiv}
          :noteon ->
            if val.channel == 1 do
              Logger.info("#{type} #{inspect(val)}")
              id = midi_sound("miditest1", val.note)
              %{state.notes | val.note => id}
              # %{state | :id => id}
              state
            else
              state
            end
          :noteoff ->
            if val.channel == 1 do
              Logger.info("#{type} #{inspect(val)}")
              set_control(state.notes[val.note], "gate", 0)
            end
            state
          :cc_event ->
            state
          _ ->
            state
        end
    message_worker(rest, s)
  end

end
