defmodule ConvertCircuits do
  require Logger

  def atom_or_nil(s) when is_nil(s) do nil end
  def atom_or_nil(s) do String.to_atom(s) end

  def read_file(fname, outdir) do
    Logger.info("convert #{fname}")
    {:ok, d} = File.read(fname)
    {:ok, ms} = Jason.decode(d)
    node_specs = Enum.map(ms["nodes"],
      fn x -> parse_node_name(x["w"], x["v"], atom_or_nil(x["control"]), x["x"], x["y"]) end)
    |> Enum.sort_by(fn n -> n.id end)

    connections = parse_connections(ms["connections"])
    |> Enum.sort_by(fn c -> c.from_node.id end)
    {:ok, enc} = Jason.encode(%{nodes: node_specs, connections: connections, master_vol: ms["master-vol"], frame: ms["frame"]})
    data = enc
    |> String.replace("},", "},\r\n")
    |> String.replace("\"connections\":", "\r\n\"connections\":\r\n")
    |> String.replace("\"nodes\":", "\r\n\"nodes\":\r\n")
    |> String.replace("\"master_vol\":", "\r\n\"master_vol\":")
    |> String.replace("\"frame\":", "\r\n\"frame\":")
    |> String.replace("{\"from", "{\r\n\"from")
    File.write(Path.join(outdir, Path.basename(fname)), data)
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

  def convert_all(from_dir, to_dir) do
    File.ls!(from_dir)
    |> Enum.filter(fn fname -> String.ends_with?(fname, ".json") end)
    |> Enum.each(fn fname -> ConvertCircuits.read_file(Path.join(from_dir, fname), to_dir) end)
  end

  def dashes_to_underscores(fname) do
    Logger.info("convert #{fname}")
    {:ok, d} = File.read(fname)
    {:ok, ms} = Jason.decode(d)
    froms = Enum.map(ms["connections"], fn c -> c["from_node"]["param_name"] end)
    tos = Enum.map(ms["connections"], fn c -> c["to_node"]["param_name"] end)
    Enum.filter(froms ++ tos, fn s -> String.contains?(s, "-") end)
  end

  def dashes_all(from_dir) do
    File.ls!(from_dir)
    |> Enum.filter(fn fname -> String.ends_with?(fname, ".json") end)
    |> Enum.filter(fn fname -> !Enum.empty?(dashes_to_underscores(Path.join(from_dir, fname))) end)
  end

end
