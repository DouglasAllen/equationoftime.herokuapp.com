module Uv

  def Uv.find_syntaxes_by_ext(ext)
    return [load_syntax(ext)] if @syntaxes.key?(ext)
    puts "No syntax found... loading all syntaxes (including all syntax.fileTypes)" if @debug
    load_all_syntaxes
    return [load_syntax(ext)] if @syntaxes.key?(ext)
    []
  end

  def Uv.find_syntaxes_by_first_line(first_line)
    return [] if first_line == ''
    puts "Searching syntaxes by first line..." if @debug
    @syntaxes.values.compact.collect do |syntax_node|
      return [syntax_node] if syntax_node && syntax_node.firstLineMatch && syntax_node.firstLineMatch =~ first_line
    end
  end

  def Uv.find_syntaxes(extensions=[], first_line='', slow_search=false)
    puts "Finding syntaxes for: Extensions: [#{extensions.join(', ')}], First Line: '#{first_line.inspect}'" if @debug
    init_syntaxes if @syntaxes.empty?
    syntaxes_found = []; extensions.delete(''); extensions.compact!
    case slow_search
    when false
       syntaxes_found << load_syntax(extensions.first) unless extensions.empty?
    when true
      syntaxes_found += extensions.collect {|ext| find_syntaxes_by_ext(ext) }.flatten.compact
      syntaxes_found += find_syntaxes_by_first_line(first_line) if syntaxes_found.empty?
    end
    syntaxes_found.compact!
    syntaxes_found << default_syntax(extensions) if syntaxes_found.empty?
    puts "Syntaxes found: [#{syntaxes_found.collect(&:name).join(', ')}]" if @debug and not syntaxes_found.empty?
    syntaxes_found
  end

  def Uv.default_syntax(extensions)
    puts "Uv Error: No syntax match found for '#{extensions.join(', ')}', defaulting to 'plain_text' syntax" if @debug
    raise "Uv Error: Syntax files failed to load (No 'plain_text' parser was loaded).  Loaded syntaxes: [#{@syntaxes.keys.join(', ')}]" unless load_syntax('plain_text')
    load_syntax('plain_text')
  end










  # Returns the Textpow::SyntaxNode for this syntax;
  # @raise ArgumentError if no syntax is found
  # Ex: syntax_node_for('ruby') => Textpow::SyntaxNode.load('ruby.syntax')
  def self.syntax_node_for(syntax)
    if !@syntaxes.key?(syntax)
      filename = File.join(@syntax_path, "#{syntax}.syntax")
      @syntaxes[syntax] = if File.exist?(filename)
        Textpow::SyntaxNode.load(filename)
      else
        false
      end
    end
    if !@syntaxes[syntax]
      if syntax == '' or syntax.nil?
        puts "No syntax supplied, defaulting to 'plain_text' syntax"
        syntax = "plain_text"
      else
        raise ArgumentError, "Syntax not found.  No #{syntax}.syntax file in #{@syntax_path}"
      end
    end
    @syntaxes[syntax]
  end



  # Guesses the correct syntax based on the input files fileType.
  # If the FileType doesnt containt a valid syntax name, each syntax
  # has it's first line matched againts the the file's first line
  def Uv.syntax_for_file file_name
    init_syntaxes unless @syntaxes
    first_line = ""
    File.open( file_name, 'r' ) { |f|
      while (first_line = f.readline).strip.size == 0; end
    }
    result = []
    @syntaxes.each do |key, value|
      assigned = false
      if value.fileTypes
        value.fileTypes.each do |t|
          if t == File.basename( file_name ) || t == File.extname( file_name )[1..-1]
            result << [key, value]
            assigned = true
            break
          end
        end
      end
      unless assigned
        if value.firstLineMatch && value.firstLineMatch =~ first_line
          result << [key, value]
        end
      end
    end
    result
  end

end