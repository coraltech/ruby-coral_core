
module Coral
module Util
class Shell < Core
  
  #-----------------------------------------------------------------------------
  # Utilities
  
  def self.exec!(command, options = {})
    min          = ( options[:min] ? options[:min].to_i : 1 )
    tries        = ( options[:tries] ? options[:tries].to_i : min )
    tries        = ( min > tries ? min : tries )
    
    info_prefix  = ( options[:info_prefix] ? options[:info_prefix] : '' )
    info_suffix  = ( options[:info_suffix] ? options[:info_suffix] : '' )
    error_prefix = ( options[:error_prefix] ? options[:error_prefix] : '' )
    error_suffix = ( options[:error_suffix] ? options[:error_suffix] : '' )
    
    ui           = ( options[:ui] ? options[:ui] : @@ui )
    
    conditions   = Coral::Event.instance(options[:exit], true)
    
    $stdout.sync = true
    $stderr.sync = true  
    
    for i in tries.downto(1)
      ui.info(">> running: #{command}")
      
      begin
        t1, output_new, output_orig, output_reader = pipe_exec_stream!($stdout, conditions, { 
          :prefix => info_prefix, 
          :suffix => info_suffix, 
        }, 'output') do |line|
          block_given? ? yield(line) : true
        end
      
        t2, error_new, error_orig, error_reader = pipe_exec_stream!($stderr, conditions, { 
          :prefix => error_prefix, 
          :suffix => error_suffix, 
        }, 'error') do |line|
          block_given? ? yield(line) : true
        end
      
        system_success = system(command)
      
      ensure
        output_success = close_exec_pipe(t1, $stdout, output_orig, output_new, 'output')
        error_success  = close_exec_pipe(t2, $stderr, error_orig, error_new, 'error')
      end
      ui.info('')
      
      success = ( system_success && output_success && error_success )
                  
      min -= 1
      break if success && min <= 0 && conditions.empty?
    end
    unless conditions.empty?
      success = false
    end
    
    return success   
  end
  
  #---
  
  def self.exec(command, options = {})
    return exec!(command, options)
  end
  
  #---
  
  def self.pipe_exec_stream!(output, conditions, options, label)
    original     = output.dup
    read, write  = IO.pipe
    
    match_prefix = ( options[:match_prefix] ? options[:match_prefix] : 'EXIT' )
            
    thread = process_stream!(read, original, options, label) do |line|
      check_conditions!(line, conditions, match_prefix) do
        block_given? ? yield(line) : true
      end
    end
    
    thread.abort_on_exception = false
    
    output.reopen(write)    
    return thread, write, original, read
  end
  
  #---
  
  def self.close_exec_pipe(thread, output, original, write, label)
    output.reopen(original)
     
    write.close
    success = thread.value
    
    original.close
    return success
  end
  
  #---
  
  def self.check_conditions!(line, conditions, match_prefix = '')
    prefix = ''
    
    unless ! conditions || conditions.empty?
      conditions.each do |key, event|
        if event.check(line)
          prefix = match_prefix
          conditions.delete(key)
        end
      end
    end
    
    result = true
    if block_given?
      result = yield
      
      unless prefix.empty?
        case result
        when Hash
          result[:prefix] = prefix
        else
          result = { :success => result, :prefix => prefix }
        end
      end
    end
    return result
  end
  
  #---
  
  def self.process_stream!(input, output, options, label)
    return Thread.new do
      success        = true      
      default_prefix = ( options[:prefix] ? options[:prefix] : '' )
      default_suffix = ( options[:suffix] ? options[:suffix] : '' )
      
      begin
        while ( data = input.readpartial(1024) )
          message = data.strip
          newline = ( data[-1,1].match(/\n/) ? true : false )
                                 
          unless message.empty?
            lines = message.split(/\n/)
            lines.each_with_index do |line, index|
              prefix  = default_prefix
              suffix  = default_suffix
              
              if block_given?
                result = yield(line)
                                          
                if result && result.is_a?(Hash)
                  prefix = result[:prefix]
                  suffix = result[:suffix]
                  result = result[:success]                 
                end
                success = result if success
              end
            
              prefix = ( prefix && ! prefix.empty? ? "#{prefix}: " : '' )
              suffix = ( suffix && ! suffix.empty? ? suffix : '' )            
              eol    = ( index < lines.length - 1 || newline ? "\n" : ' ' )
            
              output.write(prefix.lstrip + line + suffix.rstrip + eol)
            end
          end
        end
      rescue EOFError
      end
      
      input.close()
      success
    end
  end
end
end
end