defmodule ReadSynthDef do
  require Logger

  def readFile(name) do
    {:ok, f} = File.read(name)
    synth_definition(f)
  end

  def synth_definition(f) do
    ftype = String.slice(f, 0..3)
    {fversion, n1} = int32(f, 4)
    {ndefs, n2} = int16(f, n1)
    %{:ftype => ftype,
      :fversion => fversion,
      :ndefs => ndefs,
      :synth_defs => synth_defs(ndefs, f, n2)
    }
  end

  def synth_defs(ndefs, _f, _index) when ndefs == 0 do [] end

  def synth_defs(ndefs, f, index) do
    Logger.info("index = #{index}")
    {name, n1} = pstring(f, index)
    Logger.info("name = #{name} n1 = #{n1}")
    {n_constants, n2} = int32(f, n1)
    Logger.info("n_constants = #{n_constants}")
    a = float_array(n_constants, f, n2)
    n3 = List.last(a)
    const_vals = Enum.take(a, length(a) - 1)
    # the last val is the index.
    [%{:name => name,
       :n_constants => n_constants,
       :const_vals => const_vals}] ++ synth_defs(ndefs - 1, f, n3)
  end

  def float_array(n, _f, index) when n == 0 do [index] end

  def float_array(n, f, index) do
    {val, n1} = float32(f, index)
    [val] ++ float_array(n-1, f, n1)
  end

  def int32(s, i) do
    <<res :: big-integer-32>> = String.slice(s, i..i+3)
    {res, i + 4}
  end

  def int16(s, i) do
    <<res :: big-integer-16>> = String.slice(s, i..i+1)
    {res, i + 2}
  end

  def int8(s, i) do
    <<res :: big-integer-8>> = String.slice(s, i..i)
    {res, i + 1}
  end

  def float32(s, i) do
    <<res :: float-size(32)>> = String.slice(s, i..i+3)
    {res, i + 4}
  end

  def pstring(s, i) do
    {size, n} = int8(s, i)
    Logger.info("size = #{size} n = #{n}")
    {String.slice(s, i+1..i+size), size + n}
  end

  end
