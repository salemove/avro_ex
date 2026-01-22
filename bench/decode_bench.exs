# Benchmark script for decode performance

# Schema definitions
int_schema = AvroEx.decode_schema!("int")
long_schema = AvroEx.decode_schema!("long")
string_schema = AvroEx.decode_schema!("string")
bytes_schema = AvroEx.decode_schema!("bytes")

array_int_schema = AvroEx.decode_schema!(~S({"type": "array", "items": "int"}))
array_string_schema = AvroEx.decode_schema!(~S({"type": "array", "items": "string"}))

map_int_schema = AvroEx.decode_schema!(~S({"type": "map", "values": "int"}))

record_schema = AvroEx.decode_schema!(~S({
  "type": "record",
  "name": "TestRecord",
  "fields": [
    {"name": "id", "type": "long"},
    {"name": "name", "type": "string"},
    {"name": "email", "type": "string"},
    {"name": "age", "type": "int"},
    {"name": "active", "type": "boolean"}
  ]
}))

nested_record_schema = AvroEx.decode_schema!(~S({
  "type": "record",
  "name": "User",
  "fields": [
    {"name": "id", "type": "long"},
    {"name": "profile", "type": {
      "type": "record",
      "name": "Profile",
      "fields": [
        {"name": "name", "type": "string"},
        {"name": "bio", "type": "string"}
      ]
    }},
    {"name": "tags", "type": {"type": "array", "items": "string"}}
  ]
}))

# Encode test data
int_encoded = AvroEx.encode!(int_schema, 123_456)
long_encoded = AvroEx.encode!(long_schema, 9_876_543_210)
string_encoded = AvroEx.encode!(string_schema, "Hello, this is a test string with some content!")
bytes_encoded = AvroEx.encode!(bytes_schema, :crypto.strong_rand_bytes(100))

small_array_encoded = AvroEx.encode!(array_int_schema, Enum.to_list(1..10))
medium_array_encoded = AvroEx.encode!(array_int_schema, Enum.to_list(1..100))
large_array_encoded = AvroEx.encode!(array_int_schema, Enum.to_list(1..1000))

string_array_encoded = AvroEx.encode!(array_string_schema, Enum.map(1..100, &"item_#{&1}"))

map_encoded = AvroEx.encode!(map_int_schema, Map.new(1..50, &{"key_#{&1}", &1}))

record_encoded = AvroEx.encode!(record_schema, %{
  "id" => 12345,
  "name" => "John Doe",
  "email" => "john.doe@example.com",
  "age" => 30,
  "active" => true
})

nested_record_encoded = AvroEx.encode!(nested_record_schema, %{
  "id" => 12345,
  "profile" => %{
    "name" => "John Doe",
    "bio" => "Software developer with 10 years of experience"
  },
  "tags" => ["elixir", "erlang", "avro", "distributed-systems"]
})

# Run benchmarks
Benchee.run(
  %{
    "int" => fn -> AvroEx.decode!(int_schema, int_encoded) end,
    "long" => fn -> AvroEx.decode!(long_schema, long_encoded) end,
    "string" => fn -> AvroEx.decode!(string_schema, string_encoded) end,
    "bytes" => fn -> AvroEx.decode!(bytes_schema, bytes_encoded) end,
    "array_int_10" => fn -> AvroEx.decode!(array_int_schema, small_array_encoded) end,
    "array_int_100" => fn -> AvroEx.decode!(array_int_schema, medium_array_encoded) end,
    "array_int_1000" => fn -> AvroEx.decode!(array_int_schema, large_array_encoded) end,
    "array_string_100" => fn -> AvroEx.decode!(array_string_schema, string_array_encoded) end,
    "map_50" => fn -> AvroEx.decode!(map_int_schema, map_encoded) end,
    "record_5_fields" => fn -> AvroEx.decode!(record_schema, record_encoded) end,
    "nested_record" => fn -> AvroEx.decode!(nested_record_schema, nested_record_encoded) end
  },
  warmup: 2,
  time: 5,
  memory_time: 2,
  print: [configuration: false]
)
