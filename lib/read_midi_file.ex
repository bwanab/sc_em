defmodule ReadMidiFile do
  require Logger
  import ConversionPrims
  import Bitwise

  def readFile(name) do
    {:ok, f} = File.read(name)
    midifile(f)
  end

  def midifile(d) do
    ftype = String.slice(d, 0..3)
    {head_size, n1} = int32(d, 4)
    {midi_format, n2} = int16(d, n1)
    {n_tracks, n3} = int16(d, n2)
    {ticks_per_quarter_note, n4} = int16(d, n3)
    {track, _} = read_track(d, n4)
    %{
      :ftype => ftype,
      :head_size => head_size,
      :midi_format => midi_format,
      :n_tracks => n_tracks,
      :ticks_per_quarter_note => ticks_per_quarter_note,
      :midi_track => track
    }
  end

  def read_track(d, n) do
    track_head = String.slice(d, n..n+3)
    {track_size, n1} = int32(d, n+4)
    {%{
        :track_head => track_head,
        :track_size => track_size,
        :midi_messages => read_messages(d, n1)
      }, n1}
  end

  def read_messages(d, n) do
    {delta, n1} = int8(d, n)
    {m_type, n2} = int8(d, n1)
    Logger.info("m_type = #{m_type}")
    cond do
      m_type == 0xFF ->
        {{meta_type, _val}, _n3} = meta_message(delta, d, n2)
        if meta_type == :end_of_track do
          []
        else
            {meta_message, n3} = meta_message(delta, d, n2)
            [meta_message] ++ read_messages(d, n3)
        end
      (m_type >= 0x80) && (m_type < 0x90) ->
        {note_message, n3} = noteoff(m_type - 0x80, delta, d, n2)
        Logger.info("#{inspect(note_message)}, #{n3}")
        [note_message] ++ read_messages(d, n3)
      (m_type >= 0x90) && (m_type < 0xA0) ->
        {note_message, n3} = note(m_type - 0x90, delta, d, n2)
        Logger.info("#{inspect(note_message)}, #{n3}")
        [note_message] ++ read_messages(d, n3)
      (m_type >= 0xB0) && (m_type < 0xC0) ->
        {control_message, n3} = control_change(m_type - 0xB0, delta, d, n2)
        Logger.info("#{inspect(control_message)}, #{n3}")
        [control_message] ++ read_messages(d, n3)
      (m_type >= 0xC0) && (m_type < 0xD0) ->
        {program_change_message, n3} = program_change(m_type - 0xC0, delta, d, n2)
        Logger.info("#{inspect(program_change_message)}, #{n3}")
        [program_change_message] ++ read_messages(d, n3)
      (m_type >= 0xD0) && (m_type < 0xE0) ->
        {aftertouch_message, n3} = aftertouch(m_type - 0xD0, delta, d, n2)
        Logger.info("#{inspect(aftertouch_message)}, #{n3}")
        [aftertouch_message] ++ read_messages(d, n3)
      (m_type >= 0xE0) && (m_type < 0xF0) ->
        {pitch_wheel_message, n3} = pitch_wheel(m_type - 0xE0, d, n2)
        Logger.info("#{inspect(pitch_wheel_message)}, #{n3}")
        [pitch_wheel_message, n3] ++ read_messages(d, n3)
    end
  end

  def meta_message(delta, d, n) do
    {meta_type, n1} = int8(d, n)
    case meta_type do
      0x58 ->
        time_sig_meta(delta, d, n1)
      0x59 ->
        key_sig_meta(delta, d, n1)
      0x2F ->
        {{:end_of_track, delta, 0}, n1}
      0x51 ->
        {{:set_time_sig, delta, 0}, n1}
      _ ->
        {{:some_other_message, delta, meta_type}, n1}
    end
  end

  def time_sig_meta(delta, d, n) do
    {_bytes, n1} = int8(d, n)
    {bpm, n2} = int8(d, n1)
    {beat, n3} = int8(d, n2)
    {ticks_per_quarter_note, n4} = int8(d, n3)
    {t32s_per_quarter_note, n5} = int8(d, n4)
    {delta, {:time_sig,
             %{:bpm => bpm,
               :beat => beat<<<1,
               :ticks_per_quarter_note => ticks_per_quarter_note,
               :t32s_per_quarter_note => t32s_per_quarter_note}},
     n5}
  end

  def key_sig_meta(delta, d, n) do
    {_bytes, n1} = int8(d, n)
    {n_sharps_flats, n1} = int8(n, n1)
    {mode, n2} = int8(d, n1)
    {delta,
     {:key_sig, %{:n_sharps_flats => n_sharps_flats,
                  :mode => if mode == 0 do :major else :minor end}},
      n2}
  end

  def note(channel, delta, d, n) do
    {note, n1} = int8(d, n)
    {vel, n2} = int8(d, n1)
    if vel == 0 do
      {{:noteoff, channel, delta, note, vel}, n2}
    else
      {{:noteon, channel, delta, note, vel}, n2}
    end
  end

  def noteoff(channel, delta, d, n) do
    {note, n1} = int8(d, n)
    {vel, n2} = int8(d, n1)
    {{:noteoff, channel, delta, note, vel}, n2}
  end

  def control_change(channel, delta, d, n) do
    {cc, n1} = int8(d, n)
    {val, n2} = int8(d, n1)
    {{:cc_event, channel, delta, cc, val}, n2}
  end

  def pitch_wheel(channel, d, n) do
    {lsb, n1} = int8(d, n)
    {msb, n2} = int8(d, n1)
    {{:pitch_wheel_event, channel, lsb, msb}, n2}
  end

  def aftertouch(channel, delta, d, n) do
    {pressure, n1} = int8(d, n)
    {{:aftertouch_event, channel, delta, pressure}, n1}
  end

  def program_change(channel, delta, d, n) do
    {program, n1} = int8(d, n)
    {{:program_change, channel, delta, program}, n1}
  end
end
