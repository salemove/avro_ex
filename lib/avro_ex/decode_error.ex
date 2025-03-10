defmodule AvroEx.DecodeError do
  @moduledoc """
  Exceptions in decoding Avro data
  """

  defexception [:message]

  @type t :: %__MODULE__{}

  @spec new(tuple()) :: t()
  def new({:invalid_string, str}) do
    message = "Invalid UTF-8 string found #{inspect(str)}."
    %__MODULE__{message: message}
  end

  def new({:invalid_binary_uuid, binary_uuid}) do
    message = "Invalid binary UUID found #{inspect(binary_uuid)}."
    %__MODULE__{message: message}
  end
end
