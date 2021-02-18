defmodule ConvertCircuits do

  def atom_or_nil(s) when is_nil(s) do nil end
  def atom_or_nil(s) do String.to_atom(s) end

  def read_file(fname) do
    {:ok, d} = File.read(fname)
    {:ok, ms} = Jason.decode(d)
    node_specs = Enum.map(ms["nodes"],
      fn x -> parse_node_name(x["w"], x["v"], atom_or_nil(x["control"]), x["x"], x["y"]) end)
    |> Enum.sort_by(fn n -> n.id end)

    connections = parse_connections(ms["connections"])
    |> Enum.sort_by(fn c -> c.from_node.id end)
    {:ok, enc} = Jason.encode(%{nodes: node_specs, connections: connections, master_vol: ms["master-vol"], frame: ms["frame"]})
    File.write(String.replace_suffix(fname, ".json", "_new.json"), String.replace(enc, "},", "},\r\n"))
  end

  def parse_node_name(s, v, control, x, y) do
    [node, id] = String.split(s, ":")
    %{id: String.to_integer(id), name: node, val: v, control: control, x: x, y: y}
  end

  def parse_connections(connections) do
    Enum.map(connections,
      fn [from, to] ->
        from_node = parse_connection_name(from)
        to_node = parse_connection_name(to)
        %{from_node: from_node,
          to_node: to_node}
      end)
  end

  def parse_connection_name(s) do
    [node_name, id_spec] = String.split(s, ":")
    [ids, param] = String.split(id_spec, "-", parts: 2)
    id = String.to_integer(ids)
    %{name: node_name, param_name: param, id: id}
  end

end
