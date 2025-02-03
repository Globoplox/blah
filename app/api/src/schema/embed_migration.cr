# Compile-time script for embedding the migrations scripts
STDOUT << Dir.glob("#{ARGV[0]}/**/*.sql").map { |filepath|
  unless /([0-9]+)__(.+)\.sql/ =~ Path[filepath].basename
    raise "Migration file #{filepath} name is not following the expected convention: <version>__<name>.sql"
  end
  {Path[Path[filepath].dirname].basename ,{$1.to_i, $2, File.read filepath}}
}.group_by(&.first).transform_values &.map &.[1]
STDOUT << " of String => Array({Int32, String, String})\n"
