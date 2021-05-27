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

  @spec read_file(String.t) :: map
  def read_file(name) do
    {:ok, f} = File.open(name, [:charlist], fn file ->
      IO.read(file, :all) end )
    midifile(f)
  end

  @spec midifile(binary) :: map
  def midifile(d) do
    {header, n} = read_header(d)
    %{header | :midi_tracks => read_tracks(d, n, header[:n_tracks])}
  end

  @spec read_header(binary) :: {map, integer}
  def read_header(d) do
    ftype = List.to_string(Enum.slice(d, 0, 4))
    {head_size, n1} = int32(d, 4)
    {midi_format, n2} = int16(d, n1)
    {n_tracks, n3} = int16(d, n2)
    {ticks_per_quarter_note, n4} = int16(d, n3)
    Logger.debug("head_size: #{head_size}, format: #{midi_format} num_tracks: #{n_tracks}")
    {%{
      :ftype => ftype,
      :head_size => head_size,
      :midi_format => midi_format,
      :n_tracks => n_tracks,
      :ticks_per_quarter_note => ticks_per_quarter_note,
      :midi_tracks => []
    }, n4}
  end

  @spec read_tracks(binary, integer, integer) :: list
  def read_tracks(_d, _n, num) when num == 0 do [] end
  def read_tracks(d, n, num) do
    {track, n1} = read_track(d, n)
    Logger.debug("#{inspect(track)}")
    [track] ++ read_tracks(d, n1, num-1)
  end

  @spec read_track(binary, integer) :: {map, integer}
  def read_track(d, n) do
    track_head = List.to_string(Enum.slice(d, n, 4))
    {track_size, n1} = int32(d, n+4)
    Logger.debug("track_head = #{track_head} track_size = #{track_size}")
    messages = read_messages(d, n1, 0, 0)
    last = List.last(messages)
    n2 = last.val.val   # the index of the next message
    {%{
        :track_head => track_head,
        :track_size => track_size,
        :midi_messages => messages
      }, n2}
  end

  @spec read_messages(binary, integer, integer, integer) :: list
  def read_messages(d, n, last_m_type, n_offset) do
    {delta, n1} = variable_length(d, n)
    {status, nx} = int8(d, n1)
    {m_type, n2} = if status < 128 do {last_m_type, n1} else {status, nx} end
    try do
      cond do
        m_type == 0xFF ->
          {meta, n3} = meta_message(delta, d, n2)
          if meta.type == :end_of_track do
            [meta, %MidiMessage {
                    type: :last,
                    val: %{:val => n3}}]
          else
            [meta] ++ read_messages(d, n3, m_type, n_offset)
          end
        (m_type >= 0x80) && (m_type < 0x90) ->
          {note_message, n3} = noteoff(1 + m_type - 0x80, delta, d, n2)
          Logger.debug("#{inspect(note_message)}, #{n3 - n_offset}")
          [note_message] ++ read_messages(d, n3, m_type, n_offset)

        (m_type >= 0x90) && (m_type < 0xA0) ->
          {note_message, n3} = note(1 + m_type - 0x90, delta, d, n2)
          Logger.debug("#{inspect(note_message)}, #{n3 - n_offset}")
          [note_message] ++ read_messages(d, n3, m_type, n_offset)

        (m_type >= 0xA0) && (m_type < 0xB0) ->
          {polyphonic_pressure_message, n3} = polyphonic_pressure(1 + m_type - 0xB0, delta, d, n2)
          [polyphonic_pressure_message] ++ read_messages(d, n3, m_type, n_offset)

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
          {pitch_wheel_message, n3} = pitch_wheel(1 + m_type - 0xE0, delta, d, n2)
          Logger.debug("#{inspect(pitch_wheel_message)}, #{n3 - n_offset}")
          [pitch_wheel_message] ++ read_messages(d, n3, m_type, n_offset)

        m_type == 0xF0 ->
          {sysex_message, n3} = sysex_message(delta, d, n2)
          Logger.debug("#{inspect(sysex_message)}, #{n3 - n_offset}")
          [sysex_message] ++ read_messages(d, n3, m_type, n_offset)
      end
    rescue
      e in CondClauseError -> Logger.warning("m_type = #{Integer.to_string(m_type, 16)} n = #{n}"); e
    end
  end


  @spec variable_length(binary, integer) :: {integer, integer}
  def variable_length(d, n) do
    variable_length(d, n, 0)
  end

  @spec variable_length(binary, integer, integer) :: {integer, integer}
  def variable_length(d, n, acc) do
    {b1, n1} = int8(d, n)
    if b1 < 128 do
      {(acc <<< 7) + b1, n1}
    else
      variable_length(d, n + 1, (acc <<< 7) + (b1 - 128))
    end
  end

  @spec sysex_message(number, binary, integer) :: {%MidiMessage{}, integer}
  def sysex_message(delta, d, n) do
    {length, n1} = variable_length(d, n)
    {%MidiMessage{
        type: :sysex_event,
        val: %{:delta => delta, :sysex => Enum.slice(d, n1, length-2)}}, n1+length}
  end

  @spec meta_message(number, binary, integer) :: {%MidiMessage{}, integer}
  def meta_message(delta, d, n) do
    {meta_type, n1} = int8(d, n)
    {length, n2} = variable_length(d, n1)
    Logger.debug("meta_type == #{Integer.to_string(meta_type, 16)} n1 = #{n1} length = #{length}")
    try do
      case meta_type do
        0x1 ->
          get_string_val(:text_event, delta, d, n2, length)
        0x2 ->
          get_string_val(:copyright_notice, delta, d, n2, length)
        0x3 ->
          get_string_val(:track_name, delta, d, n2, length)
        0x4 ->
          get_string_val(:instrument_name, delta, d, n2, length)
        0x5 ->
          get_string_val(:lyrics_text, delta, d, n2, length)
        0x6 ->
          get_string_val(:marker, delta, d, n2, length)
        0x20 ->
          {val, n3} = int8(d, n2)
          {%MidiMessage{
              type: :midi_channel_prefix,
              val: %{:delta => delta, :val => val}}, n3}
        0x21 ->
          {val, n3} = int8(d, n2)
          {%MidiMessage{
              type: :midi_port,
              val: %{:delta => delta, :val => val}}, n3}
        0x54 ->
          smpte_offset(delta, d, n2)
        0x58 ->
          time_sig_meta(delta, d, n2)
        0x59 ->
          key_sig_meta(delta, d, n2)
        0x2F ->
          {%MidiMessage{
              type: :end_of_track,
              val: %{:delta => delta, :val => 0}}, n2}
        0x51 ->
          {val, n3} = int24(d, n2)
          {%MidiMessage{
              type: :tempo,
              val: %{:delta => delta, :val => val}}, n3}
        0x7F ->
          get_string_val(:sequencer_specific_event, delta, d, n2, length)
      end
    rescue
      e in CaseClauseError -> Logger.warning("meta_type = #{meta_type} n = #{n}"); e
    end
  end

  @spec get_string_val(:text_event | :copyright_notice | :track_name | :instrument_name | :lyrics_text | :marker | :sequencer_specific_event, number, binary, integer, integer) :: {%MidiMessage{}, integer}
  def get_string_val(event, delta, d, n, length) do
    val = if length == 0 do "" else List.to_string(Enum.slice(d, n, length)) end
    {%MidiMessage{
        type: event,
        val: %{:delta => delta, :val => val}}, n + length}
  end

  @spec smpte_offset(number, binary, integer) :: {%MidiMessage{}, integer}
  def smpte_offset(delta, d, n) do
    {hr, n1} = int8(d, n)
    {mn, n2} = int8(d, n1)
    {se, n3} = int8(d, n2)
    {fr, n4} = int8(d, n3)
    {ff, n5} = int8(d, n4)
    {%MidiMessage{
        type: :smpte_offset,
        val: %{:hr => hr,
               :mn => mn,
               :se => se,
               :fr => fr,
               :ff => ff,
               :delta => delta}},
     n5}
  end



  @spec time_sig_meta(number, binary, integer) :: {%MidiMessage{}, integer}
  def time_sig_meta(delta, d, n) do
    {bpm, n1} = int8(d, n)
    {beat, n2} = int8(d, n1)
    {ticks_per_quarter_note, n3} = int8(d, n2)
    {t32s_per_quarter_note, n4} = int8(d, n3)
    {%MidiMessage{
        type: :time_sig,
        val: %{:bpm => bpm,
               :beat => :math.pow(2, beat),
               :ticks_per_quarter_note => ticks_per_quarter_note,
               :t32s_per_quarter_note => t32s_per_quarter_note,
               :delta => delta}},
     n4}
  end

  @spec key_sig_meta(number, binary, integer) :: {%MidiMessage{}, integer}
  def key_sig_meta(delta, d, n) do
    {n_sharps_flats, n1} = int8_signed(d, n)
    {mode, n2} = int8_signed(d, n1)
    key = MusicPrims.key(if mode == 0 do :major else :minor end, n_sharps_flats)
    {%MidiMessage{
        type: :key_sig,
        val: %{:key => key,
               :delta => delta}},
     n2}
  end

  @spec note(integer, number, binary, integer) :: {%MidiMessage{}, integer}
  def note(channel, delta, d, n) do
    {note, n1} = int8(d, n)
    {vel, n2} = int8(d, n1)
    if vel == 0 do
      {%MidiMessage{
          type: :noteoff,
          val: %{:channel => channel, :delta => delta, :note => note, :vel => vel}}, n2}
    else
      {%MidiMessage{
          type: :noteon,
          val: %{:channel => channel, :delta => delta, :note => note, :vel => vel}}, n2}
    end
  end

  @spec noteoff(integer, number, binary, integer) :: {%MidiMessage{}, integer}
  def noteoff(channel, delta, d, n) do
    {note, n1} = int8(d, n)
    {vel, n2} = int8(d, n1)
    {%MidiMessage{
        type: :noteoff,
        val: %{:channel => channel, :delta => delta, :note => note, :vel => vel}}, n2}
  end

  @spec polyphonic_pressure(integer, number, binary, integer) :: {%MidiMessage{}, integer}
  def polyphonic_pressure(channel, delta, d, n) do
    {note, n1} = int8(d, n)
    {val, n2} = int8(d, n1)
    {%MidiMessage{
        type: :polyphonic_pressure_event,
        val: %{:channel => channel, :delta => delta, :note => note, :val => val}}, n2}
  end

  @spec control_change(integer, number, binary, integer) :: {%MidiMessage{}, integer}
  def control_change(channel, delta, d, n) do
    {cc, n1} = int8(d, n)
    {val, n2} = int8(d, n1)
    {%MidiMessage{
        type: :cc_event,
        val: %{:channel => channel, :delta => delta, :cc => cc, :val => val}}, n2}
  end

  @spec pitch_wheel(integer, number, binary, integer) :: {%MidiMessage{}, integer}
  def pitch_wheel(channel, delta, d, n) do
    {lsb, n1} = int8(d, n)
    {msb, n2} = int8(d, n1)
    {%MidiMessage{
        type: :pitch_wheel_event,
        val: %{:channel => channel, :delta => delta, :lsb => lsb, :msb => msb}}, n2}
  end

  @spec aftertouch(integer, number, binary, integer) :: {%MidiMessage{}, integer}
  def aftertouch(channel, delta, d, n) do
    {pressure, n1} = int8(d, n)
    {%MidiMessage{
        type: :aftertouch_event,
        val: %{:channel => channel, :delta => delta, :pressure => pressure}}, n1}
  end

  @spec program_change(integer, number, binary, integer) :: {%MidiMessage{}, integer}
  def program_change(channel, delta, d, n) do
    {program, n1} = int8(d, n)
    {%MidiMessage{
        type: :program_change,
        val: %{:channel => channel, :delta => delta, :program => program + 1}}, n1}
  end
 end
