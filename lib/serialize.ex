defmodule Serialize do
  require Logger

  @spec encode(map) :: binary
  def encode(midi) do
    midi
    |> Jason.encode!()
    |> String.replace(",", ",\r\n")
  end

  @spec decode(binary) :: map
  def decode(je) do
    je
    |> String.replace(",\r\n", ",")
    |> Jason.decode!()
    |> strings_to_atoms()
  end

  @spec strings_to_atoms(map) :: map
  def strings_to_atoms(s) when is_map(s) do
    Enum.reduce(Map.keys(s), %{},
      fn k, acc ->
        Map.put(acc, String.to_atom(k),
        case k do
            "midi_tracks" ->
              decode_track(s[k])
            "midi_messages" ->
              decode_messages(s[k])
            "key" ->
              String.to_atom(s[k])
            "sysex" ->
              s[k]
            _ ->
              strings_to_atoms(s[k])
          end) end)
  end

  @spec strings_to_atoms(list) :: {atom, map}
  def strings_to_atoms([fst|rest]) do
    Logger.info("fst = #{fst}")
    {String.to_atom(fst), strings_to_atoms(List.first(rest))}
  end

  @spec strings_to_atoms(binary) :: binary
  def strings_to_atoms(s) do
    s
  end

  @doc """
  JSON.encode encodes a list of tuples like
  [{:x, :y}, {:a, :b}]
  as a map %{:x => :y, :a => :b}

  To me, that's a bug, but since it is in specific places it can
  be remediated easily.
  """
  @spec decode_messages([map]) :: [%MidiMessage{}]
  def decode_messages(l) do
    Enum.map(l, fn m -> %MidiMessage{type: String.to_atom(m["type"]), val: strings_to_atoms(m["val"])} end)
  end

  @spec decode_track([binary]) :: [atom]
  def decode_track(l) do
    Enum.map(l, fn x -> strings_to_atoms(x) end)
  end
end
