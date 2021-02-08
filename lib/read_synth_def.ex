defmodule ReadSynthDef do
  import ConversionPrims
  require Logger

  def read_file(name) do
    {:ok, f} = File.open(name, [:charlist], fn file ->
      IO.read(file, :all) end )
    synth_definition(f)
  end

  def synth_definition(f) do
    ftype = List.to_string(Enum.slice(f, 0, 4))
    {fversion, n1} = int32(f, 4)
    {ndefs, n2} = int16(f, n1)
    {synth_defs, _} = get_array(ndefs, f, n2, &synth_def_val/2)
    %{:ftype => ftype,
      :fversion => fversion,
      :ndefs => ndefs,
      :synth_defs => synth_defs
    }
  end

  def synth_def_val(f, index) do
    Logger.debug("index = #{index}")
    {name, n1} = pstring(f, index)
    Logger.debug("name = #{name} n1 = #{n1}")
    {n_constants, n2} = int32(f, n1)
    Logger.debug("n_constants = #{n_constants}")
    {const_vals, n3} = get_array(n_constants, f, n2, &float32/2)
    {n_parameters, n4} = int32(f, n3)
    {parameter_vals, n5} = get_array(n_parameters, f, n4, &float32/2)
    {n_parameter_names, n6} = int32(f, n5)
    {parameter_names, n7} = get_array(n_parameter_names, f, n6, &parameter_name_val/2)
    {n_ugens, n8} = int32(f, n7)
    {ugens, n9} = get_array(n_ugens, f, n8, &ugen_val/2)
    {n_variants, n10} = int16(f, n9)
    {variants, _} = get_array(n_variants, f, n10, &variant_val/2)

    # the last val is the index.
    {%{:name => name,
       :n_constants => n_constants,
       :const_vals => const_vals,
       :n_parameters => n_parameters,
       :parameter_vals => parameter_vals,
       :parameter_names => parameter_names,
       :n_ugens => n_ugens,
       :ugens => ugens,
       :n_variants => n_variants,
       :variants => variants
      }, n3}
  end


  def ugen_val(f, index) do
    {ugen_name, n1} = pstring(f, index)
    {calc_rate, n2} = int8(f, n1)
    {n_inputs, n3} = int32(f, n2)
    {n_outputs, n4} = int32(f, n3)
    {special_index, n5} = int16(f, n4)
    {inputs, n6} = get_array(n_inputs, f, n5, &input_val/2)
    {outputs, n7} = get_array(n_outputs, f, n6, &int8/2)
    {
      %{
        :ugen_name => ugen_name,
        :calc_rate => calc_rate,
        :n_inputs => n_inputs,
        :n_outputs => n_outputs,
        :special_index => special_index,
        :inputs => inputs,
        :outputs => outputs
     }, n7}
  end


  def input_val(f, index) do
    {ugen_index, n1} = int32(f, index)
    {other_index, n2} = int32(f, n1)
    {%{:ugen_index => ugen_index,
       :other_index => other_index}, n2}
  end

  def parameter_name_val(f, index) do
    {val, n1} = pstring(f, index)
    {val_index, n2} = int32(f, n1)
    {{val, val_index}, n2}
  end

  def variant_val(f, index) do
    {name, n1} = pstring(f, index)
    {parameter, n2} = int32(f, n1)
    {{name, parameter}, n2}
  end

  ##
  ## Generic array getter
  ##

  def get_array_help(n, _data, index, _fun) when n == 0 do [index] end

  def get_array_help(n, data, index, fun) do
    {vals, new_index} = fun.(data, index)
    [vals] ++ get_array_help(n-1, data, new_index, fun)
  end


  def get_array(n, data, index, fun) do
    vals_and_index_from_array(get_array_help(n, data, index, fun))
  end

  def vals_and_index_from_array(a) do
    {Enum.take(a, length(a) - 1), List.last(a)}
  end

end
