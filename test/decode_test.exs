defmodule AvroEx.Decode.Test do
  use ExUnit.Case, async: true

  alias AvroEx.DecodeError

  describe "decode (primitive)" do
    test "null" do
      {:ok, schema} = AvroEx.decode_schema(~S("null"))
      {:ok, avro_message} = AvroEx.encode(schema, nil)
      assert {:ok, nil} = AvroEx.decode(schema, avro_message)
    end

    test "boolean" do
      {:ok, schema} = AvroEx.decode_schema(~S("boolean"))
      {:ok, true_message} = AvroEx.encode(schema, true)
      {:ok, false_message} = AvroEx.encode(schema, false)

      assert {:ok, true} = AvroEx.decode(schema, true_message)
      assert {:ok, false} = AvroEx.decode(schema, false_message)
    end

    test "integer" do
      {:ok, schema} = AvroEx.decode_schema(~S("int"))
      {:ok, zero} = AvroEx.encode(schema, 0)
      {:ok, neg_ten} = AvroEx.encode(schema, -10)
      {:ok, ten} = AvroEx.encode(schema, 10)
      {:ok, big} = AvroEx.encode(schema, 5_000_000)
      {:ok, small} = AvroEx.encode(schema, -5_000_000)
      {:ok, min_int32} = AvroEx.encode(schema, -2_147_483_648)
      {:ok, max_int32} = AvroEx.encode(schema, 2_147_483_647)

      assert {:ok, 0} = AvroEx.decode(schema, zero)
      assert {:ok, -10} = AvroEx.decode(schema, neg_ten)
      assert {:ok, 10} = AvroEx.decode(schema, ten)
      assert {:ok, 5_000_000} = AvroEx.decode(schema, big)
      assert {:ok, -5_000_000} = AvroEx.decode(schema, small)
      assert {:ok, -2_147_483_648} = AvroEx.decode(schema, min_int32)
      assert {:ok, 2_147_483_647} = AvroEx.decode(schema, max_int32)
    end

    test "long" do
      {:ok, schema} = AvroEx.decode_schema(~S("long"))
      {:ok, zero} = AvroEx.encode(schema, 0)
      {:ok, neg_ten} = AvroEx.encode(schema, -10)
      {:ok, ten} = AvroEx.encode(schema, 10)
      {:ok, big} = AvroEx.encode(schema, 2_147_483_647)
      {:ok, small} = AvroEx.encode(schema, -2_147_483_647)
      {:ok, min_int64} = AvroEx.encode(schema, -9_223_372_036_854_775_808)
      {:ok, max_int64} = AvroEx.encode(schema, 9_223_372_036_854_775_807)

      assert {:ok, 0} = AvroEx.decode(schema, zero)
      assert {:ok, -10} = AvroEx.decode(schema, neg_ten)
      assert {:ok, 10} = AvroEx.decode(schema, ten)
      assert {:ok, 2_147_483_647} = AvroEx.decode(schema, big)
      assert {:ok, -2_147_483_647} = AvroEx.decode(schema, small)
      assert {:ok, -9_223_372_036_854_775_808} = AvroEx.decode(schema, min_int64)
      assert {:ok, 9_223_372_036_854_775_807} = AvroEx.decode(schema, max_int64)
    end

    test "float" do
      {:ok, schema} = AvroEx.decode_schema(~S("float"))
      {:ok, zero} = AvroEx.encode(schema, 0.0)
      {:ok, big} = AvroEx.encode(schema, 256.25)

      assert {:ok, 0.0} = AvroEx.decode(schema, zero)
      assert {:ok, 256.25} = AvroEx.decode(schema, big)
    end

    test "double" do
      {:ok, schema} = AvroEx.decode_schema(~S("double"))
      {:ok, zero} = AvroEx.encode(schema, 0.0)
      {:ok, big} = AvroEx.encode(schema, 256.25)

      assert {:ok, 0.0} = AvroEx.decode(schema, zero)
      assert {:ok, 256.25} = AvroEx.decode(schema, big)
    end

    test "bytes" do
      {:ok, schema} = AvroEx.decode_schema(~S("bytes"))
      {:ok, bytes} = AvroEx.encode(schema, <<222, 213, 194, 34, 58, 92, 95, 62>>)

      assert {:ok, <<222, 213, 194, 34, 58, 92, 95, 62>>} = AvroEx.decode(schema, bytes)
    end

    test "string" do
      {:ok, schema} = AvroEx.decode_schema(~S("string"))
      {:ok, bytes} = AvroEx.encode(schema, "Hello there 🕶")

      assert {:ok, "Hello there 🕶"} = AvroEx.decode(schema, bytes)
    end
  end

  describe "complex types" do
    test "record" do
      {:ok, schema} = AvroEx.decode_schema(~S({"type": "record", "name": "MyRecord", "fields": [
        {"type": "int", "name": "a"},
        {"type": "int", "name": "b", "aliases": ["c", "d"]},
        {"type": "string", "name": "e"}
      ]}))

      {:ok, encoded_message} = AvroEx.encode(schema, %{"a" => 1, "b" => 2, "e" => "Hello world!"})

      assert {:ok, %{"a" => 1, "b" => 2, "e" => "Hello world!"}} = AvroEx.decode(schema, encoded_message)
    end

    test "union" do
      {:ok, schema} = AvroEx.decode_schema(~S(["null", "int"]))

      {:ok, encoded_null} = AvroEx.encode(schema, nil)
      {:ok, encoded_int} = AvroEx.encode(schema, 25)

      assert {:ok, nil} = AvroEx.decode(schema, encoded_null)
      assert {:ok, 25} = AvroEx.decode(schema, encoded_int)
    end

    test "union with DateTime" do
      {:ok, schema} = AvroEx.decode_schema(~S(["null", {"type": "long", "logicalType":"timestamp-micros"}]))
      datetime = DateTime.utc_now()

      {:ok, encoded_null} = AvroEx.encode(schema, nil)
      {:ok, encoded_datetime} = AvroEx.encode(schema, datetime)

      assert {:ok, nil} = AvroEx.decode(schema, encoded_null)
      assert {:ok, ^datetime} = AvroEx.decode(schema, encoded_datetime)
    end

    test "union with Time" do
      {:ok, schema} = AvroEx.decode_schema(~S(["null", {"type": "long", "logicalType":"time-micros"}]))
      time = Time.utc_now()

      {:ok, encoded_null} = AvroEx.encode(schema, nil)
      {:ok, encoded_time} = AvroEx.encode(schema, time)

      assert {:ok, nil} = AvroEx.decode(schema, encoded_null)
      assert {:ok, ^time} = AvroEx.decode(schema, encoded_time)
    end

    test "decode tagged named possibility" do
      record_json_factory = fn name ->
        ~s"""
          {
            "type": "record",
            "name": "#{name}",
            "fields": [
              {"type": "string", "name": "value"}
            ]
          }
        """
      end

      {:ok, schema} = AvroEx.decode_schema(~s([#{record_json_factory.("a")}, #{record_json_factory.("b")}]))

      {:ok, encoded_a} = AvroEx.encode(schema, {"a", %{"value" => "hello"}})
      {:ok, encoded_b} = AvroEx.encode(schema, {"b", %{"value" => "hello"}})

      assert {:ok, %{"value" => "hello"}} = AvroEx.decode(schema, encoded_a)
      assert {:ok, %{"value" => "hello"}} = AvroEx.decode(schema, encoded_b)

      assert {:ok, {"a", %{"value" => "hello"}}} = AvroEx.decode(schema, encoded_a, tagged_unions: true)
      assert {:ok, {"b", %{"value" => "hello"}}} = AvroEx.decode(schema, encoded_b, tagged_unions: true)
    end

    test "array with negative count" do
      {:ok, schema} = AvroEx.decode_schema(~S({"type": "array", "items": ["null", "int"]}))
      {:ok, _long_schema} = AvroEx.decode_schema("long")

      {:ok, encoded_array} = AvroEx.encode(schema, [1, 2, 3, nil, 4, 5, nil], include_block_byte_size: true)

      assert {:ok, [1, 2, 3, nil, 4, 5, nil]} = AvroEx.decode(schema, encoded_array)
    end

    test "array" do
      {:ok, schema} = AvroEx.decode_schema(~S({"type": "array", "items": ["null", "int"]}))

      {:ok, encoded_array} = AvroEx.encode(schema, [1, 2, 3, nil, 4, 5, nil])

      assert {:ok, [1, 2, 3, nil, 4, 5, nil]} = AvroEx.decode(schema, encoded_array)
    end

    test "empty array" do
      {:ok, schema} = AvroEx.decode_schema(~S({"type": "array", "items": ["null", "int"]}))

      {:ok, encoded_array} = AvroEx.encode(schema, [])

      assert {:ok, []} = AvroEx.decode(schema, encoded_array)
    end

    test "map" do
      {:ok, schema} = AvroEx.decode_schema(~S({"type": "map", "values": ["null", "int"]}))

      {:ok, encoded_array} = AvroEx.encode(schema, %{"a" => 1, "b" => nil, "c" => 3})

      assert {:ok, %{"a" => 1, "b" => nil, "c" => 3}} = AvroEx.decode(schema, encoded_array)
    end

    test "empty map" do
      {:ok, schema} = AvroEx.decode_schema(~S({"type": "map", "values": ["null", "int"]}))

      {:ok, encoded_map} = AvroEx.encode(schema, %{})

      assert {:ok, %{}} = AvroEx.decode(schema, encoded_map)
    end

    test "enum" do
      {:ok, schema} =
        AvroEx.decode_schema(~S({"type": "enum", "name": "Suit", "symbols": ["heart", "spade", "diamond", "club"]}))

      {:ok, club} = AvroEx.encode(schema, "club")
      {:ok, heart} = AvroEx.encode(schema, "heart")
      {:ok, diamond} = AvroEx.encode(schema, "diamond")
      {:ok, spade} = AvroEx.encode(schema, "spade")

      assert {:ok, "club"} = AvroEx.decode(schema, club)
      assert {:ok, "heart"} = AvroEx.decode(schema, heart)
      assert {:ok, "diamond"} = AvroEx.decode(schema, diamond)
      assert {:ok, "spade"} = AvroEx.decode(schema, spade)
    end

    test "fixed" do
      {:ok, schema} = AvroEx.decode_schema(~S({"type": "fixed", "name": "SHA", "size": 40}))
      sha = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
      {:ok, encoded_sha} = AvroEx.encode(schema, sha)
      assert {:ok, ^sha} = AvroEx.decode(schema, encoded_sha)
    end

    test "record with empty array of records" do
      {:ok, schema} = AvroEx.decode_schema(~S(
        {
          "type": "record",
          "name": "User",
          "fields": [
            {
              "name": "friends",
              "type": {
                "type": "array",
                "items": {
                  "type": "record",
                  "name": "Friend",
                  "fields": [
                    {
                      "name": "userId",
                      "type": "string"
                    }
                  ]
                }
              }
            },
            {
              "name": "username",
              "type": "string"
            }
          ]
        }
      ))

      {:ok, encoded} = AvroEx.encode(schema, %{"friends" => [], "username" => "iamauser"})

      assert {:ok, %{"friends" => [], "username" => "iamauser"}} = AvroEx.decode(schema, encoded)
    end
  end

  describe "decode logical types" do
    test "date" do
      assert %AvroEx.Schema{} = schema = AvroEx.decode_schema!(%{"type" => "int", "logicalType" => "date"})

      date1 = ~D[1970-01-01]
      assert {:ok, encoded} = AvroEx.encode(schema, date1)
      assert {:ok, ^date1} = AvroEx.decode(schema, encoded)

      date2 = ~D[1970-03-01]
      assert {:ok, encoded} = AvroEx.encode(schema, date2)
      assert {:ok, ^date2} = AvroEx.decode(schema, encoded)
    end

    test "datetime micros" do
      now = DateTime.utc_now()

      {:ok, micro_schema} = AvroEx.decode_schema(~S({"type": "long", "logicalType":"timestamp-micros"}))

      {:ok, micro_encode} = AvroEx.encode(micro_schema, now)
      assert {:ok, ^now} = AvroEx.decode(micro_schema, micro_encode)
    end

    test "datetime millis" do
      now = DateTime.truncate(DateTime.utc_now(), :millisecond)

      {:ok, milli_schema} = AvroEx.decode_schema(~S({"type": "long", "logicalType":"timestamp-millis"}))

      {:ok, milli_encode} = AvroEx.encode(milli_schema, now)
      assert {:ok, ^now} = AvroEx.decode(milli_schema, milli_encode)
    end

    test "datetime nanos" do
      now = DateTime.utc_now()

      {:ok, nano_schema} = AvroEx.decode_schema(~S({"type": "long", "logicalType":"timestamp-nanos"}))

      {:ok, nano_encode} = AvroEx.encode(nano_schema, now)
      assert {:ok, ^now} = AvroEx.decode(nano_schema, nano_encode)
    end

    test "time micros" do
      now = Time.truncate(Time.utc_now(), :microsecond)

      {:ok, micro_schema} = AvroEx.decode_schema(~S({"type": "long", "logicalType":"time-micros"}))
      {:ok, micro_encode} = AvroEx.encode(micro_schema, now)
      assert {:ok, ^now} = AvroEx.decode(micro_schema, micro_encode)
    end

    test "time millis" do
      now = Time.truncate(Time.utc_now(), :millisecond)

      {:ok, milli_schema} = AvroEx.decode_schema(~S({"type": "int", "logicalType":"time-millis"}))
      {:ok, milli_encode} = AvroEx.encode(milli_schema, now)
      {:ok, time} = AvroEx.decode(milli_schema, milli_encode)

      assert Time.truncate(time, :millisecond) == now
    end

    test "decimal" do
      schema = "test/fixtures/decimal.avsc" |> File.read!() |> AvroEx.decode_schema!()
      # This reference file was encoded using avro's reference implementation:
      #
      # ```java
      # Conversions.DecimalConversion conversion = new Conversions.DecimalConversion();
      # BigDecimal bigDecimal = new BigDecimal(valueInString);
      # return conversion.toBytes(bigDecimal, schema, logicalType);
      # ```
      result = AvroEx.decode!(schema, File.read!("test/fixtures/decimal.avro"), decimals: :exact)

      assert result == %{
               "decimalField1" => Decimal.new("1.23456789E-7"),
               "decimalField2" => Decimal.new("4.54545454545E-35"),
               "decimalField3" => Decimal.new("-111111111.1"),
               "decimalField4" => Decimal.new("5.3E-11")
             }

      result_approximate_values = AvroEx.decode!(schema, File.read!("test/fixtures/decimal.avro"))

      assert result_approximate_values == %{
               "decimalField1" => 1.2345678900000002e-7,
               "decimalField2" => 4.54545454545e-35,
               "decimalField3" => -111_111_111.10000001,
               "decimalField4" => 5.3e-11
             }
    end

    test "16 byte fixed uuid" do
      {:ok, fixed_uuid_schema} =
        AvroEx.decode_schema(~S({"type": "fixed", "size": 16, "name": "fixed_uuid", "logicalType":"uuid"}))

      # Example from https://en.wikipedia.org/wiki/Universally_unique_identifier#Textual_representation
      canonical_string = "550e8400-e29b-41d4-a716-446655440000"
      binary = :binary.encode_unsigned(113_059_749_145_936_325_402_354_257_176_981_405_696)

      assert {:ok, ^binary} = AvroEx.decode(fixed_uuid_schema, binary, uuid_format: :binary)
      assert {:ok, ^binary} = AvroEx.decode(fixed_uuid_schema, binary)

      assert {:ok, ^canonical_string} = AvroEx.decode(fixed_uuid_schema, binary, uuid_format: :canonical_string)
    end
  end

  describe "DecodingError" do
    test "invalid utf string" do
      assert schema = AvroEx.decode_schema!("string")

      assert_raise DecodeError, "Invalid UTF-8 string found <<104, 101, 108, 108, 255>>.", fn ->
        AvroEx.decode!(schema, <<"\nhell", 0xFFFF::16>>)
      end
    end

    test "invalid fixed uuid" do
      {:ok, fixed_uuid_schema} =
        AvroEx.decode_schema(~S({"type": "fixed", "size": 16, "name": "fixed_uuid", "logicalType":"uuid"}))

      non_uuid_binary = :binary.list_to_bin(List.duplicate(1, 16))

      assert_raise DecodeError,
                   "Invalid binary UUID found <<1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1>>.",
                   fn ->
                     AvroEx.decode!(fixed_uuid_schema, non_uuid_binary, uuid_format: :canonical_string)
                   end
    end
  end
end
