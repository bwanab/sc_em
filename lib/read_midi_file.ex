defmodule ReadMidiFile do
  require Logger
  import ConversionPrims
  import Bitwise

  @doc """
  http://www.somascape.org/midi/tech/mfile.html#midi
  http://www33146ue.sakura.ne.jp/staff/iz/formats/midi.html
  http://www.ccarh.org/courses/253/assignment/midifile/
  http://www.music.mcgill.ca/~ich/classes/mumt306/StandardMIDIfileformat.html#BM3_1
  """

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
    Logger.debug("head_size: #{head_size}, format: #{midi_format} num_tracks: #{n_tracks}")
    tracks = read_tracks(d, n4, n_tracks)
    %{
      :ftype => ftype,
      :head_size => head_size,
      :midi_format => midi_format,
      :n_tracks => n_tracks,
      :ticks_per_quarter_note => ticks_per_quarter_note,
      :midi_track => tracks
    }
  end

  def read_tracks(_d, _n, num) when num == 0 do [] end
  def read_tracks(d, n, num) do
    {track, n1} = read_track(d, n)
    Logger.debug("#{inspect(track)}")
    [track] ++ read_tracks(d, n1, num-1)
  end

  def read_track(d, n) do
    track_head = String.slice(d, n..n+3)
    {track_size, n1} = int32(d, n+4)
    Logger.debug("track_head = #{track_head} track_size = #{track_size}")
    messages = read_messages(d, n1, 0, 0)
    {_, _, n2} = List.last(messages)
    {%{
        :track_head => track_head,
        :track_size => track_size,
        :midi_messages => messages
      }, n2}
  end

  def read_messages(d, n, last_m_type, n_offset) do
    {delta, n1} = variable_length(d, n)
    {status, nx} = int8(d, n1)
    {m_type, n2} = if status < 128 do {last_m_type, n1} else {status, nx} end
    # {m_type, n2} = int8(d, n1)
    # Logger.debug("delta = #{delta} m_type = #{Integer.to_string(m_type, 16)} n = #{n}")
    cond do
      m_type == 0xFF ->
        {{meta_type, val}, n3} = meta_message(delta, d, n2)
        if meta_type == :end_of_track do
          [{meta_type, delta, n3}]
        else
          meta_message = {meta_type, val}
          # Logger.debug("#{inspect(meta_message)}, #{n3 - n_offset}")
          [meta_message] ++ read_messages(d, n3, m_type, n_offset)
        end
      (m_type >= 0x80) && (m_type < 0x90) ->
        {note_message, n3} = noteoff(1 + m_type - 0x80, delta, d, n2)
        Logger.debug("#{inspect(note_message)}, #{n3 - n_offset}")
        [note_message] ++ read_messages(d, n3, m_type, n_offset)
      (m_type >= 0x90) && (m_type < 0xA0) ->
        {note_message, n3} = note(1 + m_type - 0x90, delta, d, n2)
        Logger.debug("#{inspect(note_message)}, #{n3 - n_offset}")
        [note_message] ++ read_messages(d, n3, m_type, n_offset)
      (m_type >= 0xB0) && (m_type < 0xC0) ->
        {control_message, n3} = control_change(1 + m_type - 0xB0, delta, d, n2)
        Logger.debug("#{inspect(control_message)}, #{n3 - n_offset}")
        [control_message] ++ read_messages(d, n3, m_type, n_offset)
      (m_type >= 0xC0) && (m_type < 0xD0) ->
        {program_change_message, n3} = program_change(1 + m_type - 0xC0, delta, d, n2)
        Logger.debug("#{inspect(program_change_message)}, #{n3 - n_offset}")
        [program_change_message] ++ read_messages(d, n3, m_type, n_offset)
      (m_type >= 0xD0) && (m_type < 0xE0) ->
        {aftertouch_message, n3} = aftertouch(1 + m_type - 0xD0, delta, d, n2)
        Logger.debug("#{inspect(aftertouch_message)}, #{n3 - n_offset}")
        [aftertouch_message] ++ read_messages(d, n3, m_type, n_offset)
      (m_type >= 0xE0) && (m_type < 0xF0) ->
        {pitch_wheel_message, n3} = pitch_wheel(1 + m_type - 0xE0, d, n2)
        Logger.debug("#{inspect(pitch_wheel_message)}, #{n3 - n_offset}")
        [pitch_wheel_message] ++ read_messages(d, n3, m_type, n_offset)
      m_type == 0xF0 ->
        {sysex_message, n3} = sysex_message(delta, d, n2)
        Logger.debug("#{inspect(sysex_message)}, #{n3 - n_offset}")
        [sysex_message] ++ read_messages(d, n3, m_type, n_offset)
      # true ->
      #   new_d = String.slice(d, 0..n) <> <<last_m_type>> <> String.slice(d, n+1..-1)
      #   # {n, new_d}
      #   read_messages(new_d, n, last_m_type, n_offset + 1) # if we don't recognize it, it must be another of the previous
     end
   end


  def variable_length(d, n) do
    variable_length(d, n, 0)
  end

  def variable_length(d, n, acc) do
    {b1, n1} = int8(d, n)
    if b1 < 128 do
      {(acc <<< 7) + b1, n1}
    else
      variable_length(d, n + 1, (acc <<< 7) + (b1 - 128))
    end
  end

  def sysex_message(delta, d, n) do
    {length, n1} = variable_length(d, n)
    {{:sysex_event, delta, String.slice(d, n1..n1+length-2)}, n1+length}
  end

  def meta_message(delta, d, n) do
    {meta_type, n1} = int8(d, n)
    # Logger.debug("meta_type == #{Integer.to_string(meta_type, 16)} n1 = #{n1}")
    {length, n2} = variable_length(d, n1)
    try do
      case meta_type do
        0x1 ->
          val = String.slice(d, n2..n2+length-1)
          {{:text_event, %{:delta => delta, :val => val}}, n2 + length}
        0x2 ->
          val = String.slice(d, n2..n2+length-1)
          {{:copyright_notice, %{:delta => delta, :val => val}}, n2 + length}
        0x3 ->
          val = String.slice(d, n2..n2+length-1)
          {{:track_name, %{:delta => delta, :val => val}}, n2 + length}
        0x4 ->
          val = String.slice(d, n2..n2+length-1)
          {{:instrument_name, %{:delta => delta, :val => val}}, n2 + length}
        0x5 ->
          val = String.slice(d, n2..n2+length-1)
          {{:lyrics_text, %{:delta => delta, :val => val}}, n2 + length}
        0x6 ->
          val = String.slice(d, n2..n2+length-1)
          {{:marker, %{:delta => delta, :val => val}}, n2 + length}
        0x20 ->
          {val, n3} = int8(d, n2)
          {{:midi_channel_prefix, %{:delta => delta, :val => val}}, n3}
        0x21 ->
          {val, n3} = int8(d, n2)
          {{:midi_port, %{:delta => delta, :val => val}}, n3}
        0x54 ->
          smpte_offset(delta, d, n2)
        0x58 ->
          time_sig_meta(delta, d, n2)
        0x59 ->
          key_sig_meta(delta, d, n2)
        0x2F ->
          {{:end_of_track, %{:delta => delta, :val => 0}}, n2}
        0x51 ->
          {val, n3} = int24(d, n2)
          {{:set_time_sig, %{:delta => delta, :val => val}}, n3}
        0x7F ->
          {val, n3} = String.slice(d, n2..n2+length-1)
          {{:sequencer_specific_event, %{:delta => delta, :val => val}}, n3}
      end
    rescue
      e in CaseClauseError -> Logger.debug("meta_type = #{meta_type} n = #{n}"); e
    end
  end

  def smpte_offset(delta, d, n) do
    {hr, n1} = int8(d, n)
    {mn, n2} = int8(d, n1)
    {se, n3} = int8(d, n2)
    {fr, n4} = int8(d, n3)
    {ff, n5} = int8(d, n4)
    {{:smpte_offset,
      %{:hr => hr,
        :mn => mn,
        :se => se,
        :fr => fr,
        :ff => ff,
        :delta => delta
      }},
     n5}
  end


  def time_sig_meta(delta, d, n) do
    {bpm, n1} = int8(d, n)
    {beat, n2} = int8(d, n1)
    {ticks_per_quarter_note, n3} = int8(d, n2)
    {t32s_per_quarter_note, n4} = int8(d, n3)
    {{:time_sig,
      %{:bpm => bpm,
        :beat => :math.pow(2, beat),
        :ticks_per_quarter_note => ticks_per_quarter_note,
        :t32s_per_quarter_note => t32s_per_quarter_note,
        :delta => delta}},
     n4}
  end

  def key_sig_meta(delta, d, n) do
    {n_sharps_flats, n1} = int8(d, n)
    {mode, n2} = int8_signed(d, n1)
    {{:key_sig,
      %{:n_sharps_flats => n_sharps_flats,
        :mode => if mode == 0 do :major else :minor end,
        :delta => delta}},
     n2}
  end

  def note(channel, delta, d, n) do
    {note, n1} = int8(d, n)
    {vel, n2} = int8(d, n1)
    if vel == 0 do
      {{:noteoff, %{:channel => channel, :delta => delta, :note => note, :vel => vel}}, n2}
    else
      {{:noteon, %{:channel => channel, :delta => delta, :note => note, :vel => vel}}, n2}
    end
  end

  def noteoff(channel, delta, d, n) do
    {note, n1} = int8(d, n)
    {vel, n2} = int8(d, n1)
    {{:noteoff, %{:channel => channel, :delta => delta, :note => note, :vel => vel}}, n2}
  end

  def control_change(channel, delta, d, n) do
    {cc, n1} = int8(d, n)
    {val, n2} = int8(d, n1)
    {{:cc_event, %{:channel => channel, :delta => delta, :cc => cc, :val => val}}, n2}
  end

  def pitch_wheel(channel, d, n) do
    {lsb, n1} = int8(d, n)
    {msb, n2} = int8(d, n1)
    {{:pitch_wheel_event, %{:channel => channel, :lsb => lsb, :msb => msb}}, n2}
  end

  def aftertouch(channel, delta, d, n) do
    {pressure, n1} = int8(d, n)
    {{:aftertouch_event, %{:channel => channel, :delta => delta, :pressure => pressure}}, n1}
  end

  def program_change(channel, delta, d, n) do
    {program, n1} = int8(d, n)
    {{:program_change, %{:channel => channel, :delta => delta, :program => program}}, n1}
  end
end
