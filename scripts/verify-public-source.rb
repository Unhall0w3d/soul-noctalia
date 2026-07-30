#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"

root = File.expand_path("..", __dir__)
plugin = File.join(root, "overview")
required = %w[
  plugin.toml
  README.md
  panel.luau
  service.luau
  widget.luau
  thumbnail.webp
  translations/en.json
]
missing = required.reject { |path| File.file?(File.join(plugin, path)) }
raise "missing required plugin files: #{missing.join(", ")}" unless missing.empty?

texts = Dir.glob(File.join(root, "**", "*"), File::FNM_DOTMATCH)
  .select do |path|
    File.file?(path) &&
      !path.end_with?(".webp") &&
      !path.start_with?(File.join(root, "scripts"), File.join(root, ".git"))
  end
  .to_h { |path| [path, File.binread(path)] }
joined = texts.values.join("\n")

forbidden = {
  "home-directory path" => %r{/home/[^/\s]+/},
  "private IPv4 address" => /\b(?:10|192\.168|172\.(?:1[6-9]|2\d|3[01]))\.\d{1,3}\.\d{1,3}\b/,
  "legacy resolved target field" => /\bssh_target\b/,
  "private key material" => /BEGIN (?:OPENSSH|RSA|EC) PRIVATE KEY/,
  "credential assignment" => /\b(?:password|token|api_key|secret)\s*=/i
}
forbidden.each do |label, pattern|
  raise "#{label} found in public source" if joined.match?(pattern)
end

manifest = File.read(File.join(plugin, "plugin.toml"))
raise "plugin id differs" unless manifest.include?('id = "soul/overview"')
raise "portable Soul command differs" unless manifest.include?('default = "soul-noctalia"')
raise "companion dependency is undeclared" unless manifest.include?('dependencies = ["soul-noctalia"]')

translation = JSON.parse(File.read(File.join(plugin, "translations", "en.json")))
%w[settings.soul_command.label settings.soul_command.description].each do |key|
  raise "missing translation: #{key}" unless translation.key?(key)
end

puts JSON.pretty_generate(
  "ok" => true,
  "lifecycle_state" => "complete",
  "plugin_id" => "soul/overview",
  "environment_specific_values" => false,
  "resolved_targets_exposed" => false
)
