defmodule AvroEx do
  @moduledoc """
  AvroEx is a library for encoding and decoding data with Avro schemas.
  Supports parsing schemas, encoding data, and decoding data.

  For encoding and decoding, the following type chart should be referenced:

  | Avro Types | Elixir Types |
  |------------|:------------:|
  | boolean | boolean |
  | integer | integer |
  | long | integer |
  | float | decimal |
  | double | decimal |
  | bytes | binary |
  | string | String.t, atom |
  | null | nil |
  | Record | map |
  | Enum | String.t, atom (corresponding to the enum's symbol list) |
  """
  alias AvroEx.Schema
  alias AvroEx.Schema.Context

  @type encoded_avro :: binary

  @doc """
  Checks to see if the given data is encodable using the given schema. Helpful for unit testing.

      iex> AvroEx.encodable?(%Schema{schema: %Primitive{type: :string}}, "wut")
      true

      iex> AvroEx.encodable?(%Schema{schema: %Primitive{type: :string}}, 12345)
      false
  """
  @spec encodable?(AvroEx.Schema.t(), any) :: boolean
  defdelegate encodable?(schema, data), to: AvroEx.Schema

  @spec parse_schema(Schema.json_schema()) :: {:ok, Schema.t()} | {:error, AvroEx.Schema.DecodeError.t()}
  @deprecated "Use AvroEx.decode_schema/1 instead"
  def parse_schema(json), do: decode_schema(json, [])

  @spec parse_schema!(Schema.json_schema()) :: Schema.t() | no_return
  @deprecated "Use AvroEx.decode_schema!/1 instead"
  def parse_schema!(json), do: decode_schema!(json, [])

  @doc """
  Given an Elixir or JSON-encoded schema, parses the schema and returns a `t:AvroEx.Schema.t/0` struct representing the schema.

  Errors for invalid JSON, invalid schemas, and bad name references.

  ## Options
  * `:strict` - whether to strictly validate the schema, defaults to `false`. Recommended to turn this on for locally owned schemas, but not for interop with external schemas.

  ## Examples

      iex> AvroEx.decode_schema("string")
      {:ok, %AvroEx.Schema{schema: %AvroEx.Schema.Primitive{type: :string}}}

      iex> json= ~S({\"fields\":[{\"name\":\"a\",\"type\":\"string\"}],\"name\":\"my_type\",\"type\":\"record\"})
      iex> {:ok, %Schema{schema: record}} = AvroEx.decode_schema(json)
      iex> match?(%Record{}, record)
      true
  """
  @spec decode_schema(term(), Keyword.t()) :: {:ok, Schema.t()} | {:error, AvroEx.Schema.DecodeError.t()}
  def decode_schema(schema, opts \\ []) do
    try do
      {:ok, decode_schema!(schema, opts)}
    rescue
      error -> {:error, error}
    end
  end

  @doc """
  Same as `AvroEx.decode_schema/1`, but raises an exception on failure instead of
  returning an error tuple.

  ## Examples

      iex> AvroEx.decode_schema!("int")
      %AvroEx.Schema{schema: %AvroEx.Schema.Primitive{type: :int}}

  """
  @spec decode_schema!(term(), Keyword.t()) :: Schema.t()
  def decode_schema!(schema, opts \\ []) do
    if is_binary(schema) and not Schema.Parser.primitive?(schema) do
      schema
      |> Jason.decode!()
      |> Schema.Parser.parse!(opts)
    else
      Schema.Parser.parse!(schema, opts)
    end
  end

  @doc """
  Encodes the given schema to JSON

  ## Options
  * `canonical` - Encodes the schema into its [Parsing Canonical Form](https://avro.apache.org/docs/current/spec.html#Parsing+Canonical+Form+for+Schemas), default `false`

  ## Examples

      iex> schema = AvroEx.decode_schema!(%{"type" => "int", "logicalType" => "date"})
      iex> AvroEx.encode_schema(schema)
      ~S({"type":"int","logicalType":"date"})

      iex> schema = AvroEx.decode_schema!(%{"type" => "int", "logicalType" => "date"})
      iex> AvroEx.encode_schema(schema, canonical: true)
      ~S("int")

  """
  @spec encode_schema(Schema.t(), Keyword.t()) :: String.t()
  def encode_schema(%Schema{} = schema, opts \\ []) do
    AvroEx.Schema.Encoder.encode(schema, opts)
  end

  @doc """
  Given `t:AvroEx.Schema.t/0` and `term()`, takes the data and encodes it according to the schema.

  ## Examples

      iex> schema = AvroEx.decode_schema!("int")
      iex> AvroEx.encode(schema, 1234)
      {:ok, <<164, 19>>}

  ## Tagged unions

  When supplying a union value one can optionally supply a tagged tuple of `{name, value}`
  instead of just the plain `value` to force encoding the value as the named type
  found using `name` instead of matching by the shape of `value`. This can improve
  performance and allows forcing a selected named type even if the shape of the
  data is the same. See also the "Tagged unions" section on `decode/3`.

  ## Array encoding

  Array encoding may add an additional `long` encoded integer to put the byte size
  of blocks with their counts. This allows consumers of the encoded data to skip
  over those blocks in an efficient manner. Using the option `include_block_byte_size: true`
  enables adding those additional values.

  ## UUID encoding

  UUIDs can be decoded as strings using the canonical hex representation with 37 bytes.
  Alternatively, encoding UUIDs in their 16 byte binary representation is much
  more compact, saving 21 bytes per encoding.
  See "UUIDs" on `decode/3` for how to convert binary representations back to
  canonical strings during decoding.
  """
  @spec encode(Schema.t(), term, keyword()) ::
          {:ok, encoded_avro} | {:error, AvroEx.EncodeError.t() | Exception.t()}
  def encode(schema, data, opts \\ []) do
    AvroEx.Encode.encode(schema, data, opts)
  end

  @doc """
  Same as `encode/2`, but returns the encoded value directly.

  Raises `t:AvroEx.EncodeError.t/0` on error.

  For documentation of `opts` see `encode/3`.

  ## Examples

      iex> schema = AvroEx.decode_schema!("boolean")
      iex> AvroEx.encode!(schema, true)
      <<1>>
  """
  @spec encode!(Schema.t(), term(), keyword()) :: encoded_avro()
  def encode!(schema, data, opts \\ []) do
    case AvroEx.Encode.encode(schema, data, opts) do
      {:ok, data} -> data
      {:error, error} -> raise error
    end
  end

  @doc """
  Given an encoded message and its accompanying schema, decodes the message.

      iex> schema = AvroEx.decode_schema!("boolean")
      iex> AvroEx.decode(schema, <<1>>)
      {:ok, true}

  ## Tagged unions

  When decoding one can set the option `tagged_unions: true` to decode union
  values as a tagged tuple of `{name, value}` instead of just the plain `value`.
  This allows to retain the information about which union schema was used for
  encoding when this cannot be infered from the `value` alone.

  ## Decimals

  Specify the option `decimals: :exact` to use `Decimal.new/3` to parse decimals
  into a Decimal struct with arbitrary precision.

  Otherwise, an approximate number is calculated.

  ## UUIDs

  When decoding a 16 byte fixed quantity with logical type "uuid", specify
  `uuid_format: :binary` to retain the binary representation or
  `uuid_format: :canonical_string` to convert to the canonical, hex as string representation.

      iex> schema = AvroEx.decode_schema!(~S({"type": "fixed", "size": 16, "name": "fixed_uuid", "logicalType":"uuid"}))
      iex> binary_uuid = <<85, 14, 132, 0, 226, 155, 65, 212, 167, 22, 68, 102, 85, 68, 0, 0>>
      iex> AvroEx.decode(schema, binary_uuid, uuid_format: :binary)
      {:ok, binary_uuid}
      iex> AvroEx.decode(schema, binary_uuid, uuid_format: :canonical_string)
      {:ok, "550e8400-e29b-41d4-a716-446655440000"}

  """
  @spec decode(Schema.t(), encoded_avro, keyword()) ::
          {:ok, term}
          | {:error, AvroEx.DecodeError.t()}
  def decode(schema, message, opts \\ []) do
    case AvroEx.Decode.decode(schema, message, opts) do
      {:ok, value, _} -> {:ok, value}
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Same as decode/2, but returns raw decoded value.

  Raises `t:AvroEx.DecodeError.t/0` on error.

  For documentation of `opts` see `decode/3`.

  ## Examples

      iex> schema = AvroEx.decode_schema!("string")
      iex> encoded = AvroEx.encode!(schema, "hello")
      iex> AvroEx.decode!(schema, encoded)
      "hello"
  """
  @spec decode!(Schema.t(), encoded_avro(), keyword()) :: term()
  def decode!(schema, message, opts \\ []) do
    case AvroEx.Decode.decode(schema, message, opts) do
      {:ok, value, _} -> value
      {:error, error} -> raise error
    end
  end

  @deprecated "Use AvroEx.Schema.Context.lookup/2"
  @spec named_type(Schema.full_name(), Schema.t() | Context.t()) :: nil | Schema.schema_types()
  def named_type(name, %Schema{context: %Context{} = context}) when is_binary(name) do
    named_type(name, context)
  end

  def named_type(name, %Context{} = context) do
    Context.lookup(context, name)
  end
end
