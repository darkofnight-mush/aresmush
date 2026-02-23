help_version = ARGV[0]

if (!help_version)
  puts "USAGE:  copy_help <version>  (e.g. 1.0)"
  exit
end

filename_friendly_help_version = help_version.gsub(".", "-")

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), *%w[engine]))

require 'fileutils'
require 'ansi'
require 'aresmush'
require 'erubis'
require 'rspec'
require 'rspec/core/rake_task'
require 'tempfile'
#require 'mongoid'
require_relative 'install/init_db.rb'
require_relative 'install/configure_game.rb'
require_relative 'plugins/help/helpers.rb'

def minimal_boot
  bootstrapper = AresMUSH::Bootstrapper.new
  bootstrapper.config_reader.load_game_config
  AresMUSH::Global.plugin_manager.load_all
  bootstrapper.help_reader.load_game_help
  bootstrapper.db.load_config
end


class String
  def titlecase
    self.downcase.strip.gsub(/\b('?[a-z])/) { $1.capitalize }
  end   
end

def plugin_title(name)
  return "AresCentral" if name == "arescentral"
  return "IC Time" if name == "ictime"
  return "OOC Time" if name == "ooctime"
  return "FS3 Skills" if name == "fs3skills"
  return "FS3 Combat" if name == "fs3combat"
  
  name.titlecase
end

def format_help(msg, filename_friendly_help_version)
    # Take escaped backslashes out of the equation for a moment because
    # they throw the other formatters off.
    msg = msg.gsub(/%\\/, "~ESCBS~")

    # Do substitutions
    msg = AresMUSH::SubstitutionFormatter.format(msg, false)

    # Replace TOC 
    msg = msg.gsub("[[toc]]", "{% include toc.html %}")
    
    # Unescape %'s
    msg = msg.gsub("\\%", "%")

    # Put the escaped backslashes back in.
    msg = msg.gsub("~ESCBS~", "\\")

    if (msg =~ /\]\(\/help\/([^\)]+)\)/)
      match = $1
      topic_name = AresMUSH::Help.find_topic(match).first
      topic = AresMUSH::Help.topic_index[topic_name]
      if (!topic)
        raise "Can't find topic #{match} in #{msg}"
      end
      
      msg = msg.gsub(/\]\(\/help\/([^\)]+)\)/, "](/help/#{filename_friendly_help_version}/#{topic['plugin']}/#{topic['topic']})")
    end
    msg
end

minimal_boot


docs_dir = "/Users/lynn/Documents/ares-docs/"
help_dir = "#{docs_dir}/help/"
if (!Dir.exist?(help_dir))
  Dir.mkdir help_dir
end


plugins = Dir['plugins/*']
plugin_names = []

toc_topics = {}

AresMUSH::Help.toc.keys.sort.each do |toc|
  toc_topics[toc] = AresMUSH::Help.toc_section_topic_data(toc)
end


File.open("#{help_dir}/index.md", 'w') do |file|
  file.puts "---"
  file.puts "title: Game Help Files - Version #{help_version}"
  file.puts "description: Game Help."
  file.puts "layout: page"
  file.puts "tags:"
  file.puts "- help-#{help_version}"
  file.puts "---"
  file.puts ""
  file.puts "These are quick links to the game help files for the current version of AresMUSH."
  file.puts ""
  toc_topics.each do |toc, topics|
    file.puts ""
    file.puts "## #{toc}"
    file.puts ""
    
    topics.select { |name, data| data['tutorial'] }.sort_by { |name, data| [data['order'] || 99, name] }.each do |name, data|
      file.puts "* [#{name.humanize}](https://mush.aresmush.com/help/#{data['topic']})"
    end

    commands = topics.select { |name, data| !data['tutorial'] }
      .sort_by { |name, data| [data['order'] || 99, name] }
      .map { |name, data| "[#{name.titleize}](https://mush.aresmush.com/help/#{data['topic']})" }
      .join( " &bull; " )

    file.puts "\n*Commands*: #{commands}"
  end
end

help_files = {
  'plugins/login/help/en/privacy.md': "#{docs_dir}/game_privacy.md",
  'plugins/manage/help/en/trouble_tutorial.md': "#{docs_dir}/tutorials/manage/trolls.md"
}

help_files.each do |src, dest|
  puts "Copying files from #{src} to #{dest}"
  orig = File.readlines src.to_s
  orig.shift
  orig.unshift "layout: help_page\n"
  orig.unshift "---\n"
    
  File.open(dest, 'w') do |f|
    new_lines = orig.map { |o| format_help(o, filename_friendly_help_version)}
    f.write new_lines.join
  end
end

puts "Done!"
