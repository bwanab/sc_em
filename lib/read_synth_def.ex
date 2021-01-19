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
    {synth_defs, _} = vals_and_index_from_array(synth_defs(ndefs, f, n2))
    %{:ftype => ftype,
      :fversion => fversion,
      :ndefs => ndefs,
      :synth_defs => synth_defs
    }
  end

  def synth_defs(ndefs, _f, index) when ndefs == 0 do [index] end

  def synth_defs(ndefs, f, index) do
    Logger.debug("index = #{index}")
    {name, n1} = pstring(f, index)
    Logger.debug("name = #{name} n1 = #{n1}")
    {n_constants, n2} = int32(f, n1)
    Logger.debug("n_constants = #{n_constants}")
    {const_vals, n3} = vals_and_index_from_array(float_array(n_constants, f, n2))
    {n_parameters, n4} = int32(f, n3)
    {parameter_vals, n5} = vals_and_index_from_array(float_array(n_parameters, f, n4))
    {n_parameter_names, n6} = int32(f, n5)
    {parameter_names, n7} = vals_and_index_from_array(param_array(n_parameter_names, f, n6))
    {n_ugens, n8} = int32(f, n7)
    {ugens, n9} = vals_and_index_from_array(ugen_array(n_ugens, f, n8))
    {n_variants, n10} = int16(f, n9)
    {variants, _} = vals_and_index_from_array(variant_array(n_variants, f, n10))

    # the last val is the index.
    [%{:name => name,
       :n_constants => n_constants,
       :const_vals => const_vals,
       :n_parameters => n_parameters,
       :parameter_vals => parameter_vals,
       :parameter_names => parameter_names,
       :n_ugens => n_ugens,
       :ugens => ugens,
       :n_variants => n_variants,
       :variants => variants
      }]
    ++ synth_defs(ndefs - 1, f, n3)
  end

  def ugen_array(n, _f, index) when n == 0 do [index] end

  def ugen_array(n, f, index) do
    {ugen_name, n1} = pstring(f, index)
    {calc_rate, n2} = int8(f, n1)
    {n_inputs, n3} = int32(f, n2)
    {n_outputs, n4} = int32(f, n3)
    {special_index, n5} = int16(f, n4)
    {inputs, n6} = vals_and_index_from_array(input_array(n_inputs, f, n5))
    {outputs, n7} = vals_and_index_from_array(output_array(n_outputs, f, n6))
    [%{
        :ugen_name => ugen_name,
        :calc_rate => calc_rate,
        :n_inputs => n_inputs,
        :n_outputs => n_outputs,
        :special_index => special_index,
        :inputs => inputs,
        :outputs => outputs
     }
    ] ++ ugen_array(n-1, f, n7)
  end

  def input_array(n, _f, index) when n == 0 do [index] end

  def input_array(n, f, index) do
    {ugen_index, n1} = int32(f, index)
    {other_index, n2} = int32(f, n1)
    [%{:ugen_index => ugen_index,
       :other_index => other_index}] ++ input_array(n-1, f, n2)
  end

  def output_array(n, _f, index) when n == 0 do [index] end

  def output_array(n, f, index) do
    {calc_rate, n1} = int8(f, index)
    [calc_rate] ++ output_array(n-1, f, n1)
  end


  def float_array(n, _f, index) when n == 0 do [index] end

  def float_array(n, f, index) do
    {val, n1} = float32(f, index)
    [val] ++ float_array(n-1, f, n1)
  end

  def param_array(n, _f, index) when n == 0 do [index] end

  def param_array(n, f, index) do
    {val, n1} = pstring(f, index)
    {index, n2} = int32(f, n1)
    [{val, index}] ++ param_array(n-1, f, n2)
  end

  def variant_array(n, _f, index) when n == 0 do [index] end

  def variant_array(n, f, index) do
    {name, n1} = pstring(f, index)
    {parameter, n2} = int32(f, n1)
    [{name, parameter}] ++ variant_array(n-1, f, n2)
  end

  def int32(s, i) do
    <<res :: signed-big-integer-32>> = String.slice(s, i..i+3)
    {res, i + 4}
  end

  def int16(s, i) do
    <<res :: signed-big-integer-16>> = String.slice(s, i..i+1)
    {res, i + 2}
  end

  def int8(s, i) do
    <<res :: signed-big-integer-8>> = String.slice(s, i..i)
    {res, i + 1}
  end

  def float32(s, i) do
    <<res :: float-size(32)>> = String.slice(s, i..i+3)
    {res, i + 4}
  end

  def pstring(s, i) do
    {size, n} = int8(s, i)
    Logger.debug("size = #{size} n = #{n}")
    {String.slice(s, i+1..i+size), size + n}
  end

  def vals_and_index_from_array(a) do
    {Enum.take(a, length(a) - 1), List.last(a)}
  end

  end
