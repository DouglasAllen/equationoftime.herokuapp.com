module Uv

  # Loads @syntaxes with all the syntax names.
  # DOES NOT load the syntax files into TextPow
  def Uv.init_syntaxes
    puts "Uv: Finding all syntax names..." if @debug
    syntax_names.each do |syntax_name|
      puts "Uv: Setting @syntax[#{syntax_name}]" if @debug and !@syntaxes.key?(syntax_name)
      @syntaxes[syntax_name] = nil unless @syntaxes.key?(syntax_name)
    end
    @syntaxes
  end

  # Loads @syntaxes with all the syntax names.
  # Load the syntax files into Textpow instences.
  # ALSO loads the declared_file_types
  # @force_reload: boolean. Forces the syntax to be reloaded, overriding any loaded syntax
  def Uv.load_all_syntaxes(force_reload=false)
    puts "Uv: Loading all syntaxes..." if @debug
    syntax_names.each do |syntax_name|
      load_syntax(syntax_name, force_reload)
      load_syntax_declared_file_types(@syntaxes[syntax_name])
    end
    @syntaxes
  end

  # Loads @syntaxes[syntax_name] with a Textpow instance
  # @force_reload: boolean. Forces the syntax to be reloaded, overriding any loaded syntax
  def Uv.load_syntax(syntax_name, force_reload=false)
    filename = File.join(@syntax_path, "#{syntax_name}.syntax")
    begin
      if force_reload
        @syntaxes[syntax_name] = Textpow::SyntaxNode.load(filename)
      else
        @syntaxes[syntax_name] ||= Textpow::SyntaxNode.load(filename)
      end
      puts "#{syntax_name}.syntax loaded" if @debug
    rescue => e
      puts "Error in loading syntax: #{syntax_name}.  Returning: #{@syntaxes[syntax_name].class}.  Error: #{e.message}" if @debug
    end
    @syntaxes[syntax_name]
  end

  def Uv.load_syntax_declared_file_types(syntax_node)
    syntax_node.fileTypes.each do |file_type|
      puts "Syntax: #{syntax_node.name} loading FileType: #{file_type}" if @debug
      @syntaxes[file_type] ||= syntax_node
    end if syntax_node and syntax_node.fileTypes
  end

end