#encoding: ascii-8bit
require 'uv/engine' if defined?(Rails)
require 'fileutils'
require 'textpow'
require 'uv/render_processor'
require "uv/version"
require "uv/finding_syntax_nodes"
require "uv/syntaxes"
require 'uv/utility'


module Uv
  class << self
    attr_accessor :render_path, :theme_path, :syntax_path, :default_style, :syntaxes, :debug
  end

  self.syntax_path   = File.join(File.dirname(__FILE__), '..', 'syntax')
  self.render_path   = File.join(File.dirname(__FILE__), '..', 'render')
  #self.theme_path    = File.join(render_path, 'xhtml', 'files', 'css')
  self.theme_path    = File.join(File.dirname(__FILE__), '..', 'vendor', 'assets', 'stylesheets')
  self.default_style = 'mac_classic'
  self.syntaxes      = {}

  # Returns the root path for Uv: ['bin','lib'...]
  def Uv.path
    result = []
    result << File.join(File.dirname(__FILE__), ".." )
  end


  # Returns the list of file names in the syntax dir (without '.syntax' extension)
  def Uv.syntax_names
    Dir.glob( File.join(@syntax_path, '*.syntax') ).collect do |f|
      File.basename(f, '.syntax')
    end
  end

  def Uv.debug=(value)
    @debug=value
  end

  # Copies files from the [ruby-uv/render/<arg1>/files/] to the <arg2> output directory
  def Uv.copy_files output, output_dir
    Uv.path.each do |dir|
      dir_name = File.join( dir, "render", output, "files" )
      FileUtils.cp_r( Dir.glob(File.join( dir_name, "." )), output_dir ) if File.exists?( dir_name )
    end
  end


  # Returns the list of .css files in the theme directory
  def Uv.themes
    Dir.glob( File.join(@theme_path, '*.css') ).collect do |f|
      File.basename(f, '.css')
    end
  end

  # Parses <arg1> text using RenderProcessor.load(Textpow::SyntaxNode.parse(text)), returns the vailid <output>
  def Uv.parse text, output = "xhtml", syntax_name = nil, line_numbers = false, render_style = nil, headers = false
    syntaxes = find_syntaxes([syntax_name], get_first_line(text))
    return text if syntaxes.empty?
    RenderProcessor.load(output, render_style, line_numbers, headers) do |processor|
      syntaxes.first.parse(text, processor)
    end.string
  end

  def Uv.get_first_line(text)
    stripped_text = text.strip
    first_break = stripped_text.index(/[\n\r]/) || stripped_text.length - 1
    stripped_text[0..first_break].strip
  end

  # Parses <arg1> text with Textpow::DebugProcessor, using the given syntax
  def Uv.debug text, syntax_name
    syntax_node_for(syntax_name).parse(text, Textpow::DebugProcessor.new)
  end


end