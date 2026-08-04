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
catalog = File.read(File.join(root, "catalog.toml"))
raise "plugin id differs" unless manifest.include?('id = "soul/overview"')
raise "plugin version differs" unless manifest.include?('version = "0.3.1"')
raise "catalog version differs from plugin" unless catalog.include?('version = "0.3.1"')
raise "portable Soul command differs" unless manifest.include?('default = "soul-noctalia"')
raise "companion dependency is undeclared" unless manifest.include?('dependencies = ["soul-noctalia"]')

panel = File.read(File.join(plugin, "panel.luau"))
widget = File.read(File.join(plugin, "widget.luau"))
raise "Free Core state is not projected" unless panel.include?('mode == "free"') && panel.include?('No model loaded')
raise "Dev Core state is not projected" unless panel.include?('mode == "dev"') && panel.include?('Development lane active')
raise "bar tooltip omits Core state" unless widget.include?('Core state: {coreStateText(core)}')
raise "panel still claims an SSH-only fleet" if panel.include?("SSH-integrated fleet") || panel.include?("No SSH-integrated devices")
raise "panel omits the integrated-fleet boundary" unless panel.include?("Integrated fleet") && panel.include?("No integrated systems")
raise "read-only device cards gained an implicit action" unless panel.include?("No interactive action is available") && panel.include?("onClick = canConnect and")

service = File.read(File.join(plugin, "service.luau"))
raise "five-Core allowlist differs" unless %w[daily amd-free music free dev].all? { |core| service.include?(%(id == "#{core}")) }
raise "Core preview schema is not enforced" unless service.include?('soul.noctalia.core_control.v1')
raise "Core activation omits exact gate fields" unless %w[--target-profile --confirmation --expected-digest].all? { |flag| service.include?(flag) }
raise "pending Core preview is not memory-only" unless service.include?('local pendingCorePreview = nil')
raise "Core selection is not a distinct two-click flow" unless panel.include?('action = "core-preview"') && panel.include?('action = "core-activate"')

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
