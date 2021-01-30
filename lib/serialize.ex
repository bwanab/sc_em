defmodule Serialize do
  require Logger


  def encode(midi) do
    {:ok, je} = Jason.encode(midi)
    String.replace(je, ",", ",\r\n")
  end

  def decode(je) do
    {:ok, s} = Jason.decode(je)
    strings_to_atoms(s)
  end

  def strings_to_atoms(s) when is_map(s) do
    Enum.reduce(Map.keys(s), %{},
      fn k, acc ->
        Map.put(acc, String.to_atom(k),
        cond do
            k == "midi_tracks" ->
              decode_track(s[k])
            k == "midi_messages" ->
              decode_messages(s[k])
            true ->
              strings_to_atoms(s[k])
          end) end)
  end

  def strings_to_atoms([fst|rest]) do
    {String.to_atom(fst), strings_to_atoms(List.first(rest))}
  end

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
  def decode_messages(l) do
    Enum.map(l, fn {k, v} -> {String.to_atom(k), strings_to_atoms(v)} end)
  end

  def decode_track(l) do
    Enum.map(l, fn x -> strings_to_atoms(x) end)
  end
end
