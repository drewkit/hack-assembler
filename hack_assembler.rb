class Nand2TetrisAssemblyDesymbolizer
  attr_reader :unprocessed_lines
  attr_accessor :labels_table

  PREDEFINED_SYMBOLS_TABLE = {
    'SP' => 0,
    'LCL' => 1,
    'ARG' => 2,
    'THIS' => 3,
    'THAT' => 4,
    'R0' => 0,
    'R1' => 1,
    'R2' => 2,
    'R3' => 3,
    'R4' => 4,
    'R5' => 5,
    'R6' => 6,
    'R7' => 7,
    'R8' => 8,
    'R9' => 9,
    'R10' => 10,
    'R11' => 11,
    'R12' => 12,
    'R13' => 13,
    'R14' => 14,
    'R15' => 15,
    'SCREEN' => 16384,
    'KBD' => 24576
  }

  def initialize(unprocessed_lines)
    @unprocessed_lines = unprocessed_lines
  end

  def self.process(lines)
    new(lines).output
  end

  def output
    delabeled_lines, @labels_table = process_out_labels(unprocessed_lines)
    variables_table = generate_variables_table(delabeled_lines)
    all_symbols = variables_table.merge(labels_table).merge(PREDEFINED_SYMBOLS_TABLE)
    desymbolize(delabeled_lines,all_symbols)
  end

  def process_out_labels(lines,labels={})
    label_line_number = nil

    lines.each_with_index do |line,i|
      label_search_result = /\(([^\s]+)\)/.match(line)
      if label_search_result
        label = label_search_result[1]
        labels[label] = label_line_number = i
        break
      end
    end

    if label_line_number
      lines[label_line_number] = nil
      lines.compact!
      process_out_labels(lines,labels)
    else
      [lines, labels]
    end
  end

  def generate_variables_table(lines)
    identified_variables = identify_variables(lines)
    establish_addresses_for_variables(identified_variables)
  end

  def identify_variables(lines)
    identified_variables = []
    lines.each do |line|
      variable_search_result = /@(\S+)/.match(line)
      if variable_search_result
        variable = variable_search_result[1]

        # skip if variable is already in actual memory address format
        next if variable.to_i.to_s == variable

        unless PREDEFINED_SYMBOLS_TABLE.has_key?(variable) || labels_table.has_key?(variable) || identified_variables.include?(variable)
          identified_variables << variable
        end
      end
    end
    identified_variables
  end
  
  def establish_addresses_for_variables(identified_variables)
    table = {}
    identified_variables.each_with_index do |var,i|
      table[var] = 16 + i
    end
    table
  end

  def desymbolize(lines, symbols)
    lines.map do |line|
      line = line.strip
      if /@/.match(line)
        line.split(" ").map do |word|
          if /@/.match(word)
            if word.sub('@','').to_i.to_s == word.sub('@','')
              word
            else
              address = symbols.fetch(word.gsub('@',''), nil)
              raise "Reference Not Found For Symbol #{word}" unless address
              "@#{address}"
            end
          else
            word
          end
        end.join(" ")
      else
        line
      end
    end
  end
end

class Nand2TetrisDesymbolizedAssemblytoMachineCode
  attr_reader :desymbolized_assembly_lines

  # 'X' represents either 'A' or 'M' register
  COMPUTATION_MAPPING = {
    '0' => '101010',
    '1' => '111111',
    '-1' => '111010',
    'D' => '001100',
    'X' => '110000',
    '!D' => '001101',
    '!X' => '110001',
    '-D' => '001111',
    '-X' => '110011',
    'D+1' => '011111',
    'X+1' => '110111',
    'D-1' => '001110',
    'X-1' => '110010',
    'D+X' => '000010',
    'D-X' => '010011',
    'X-D' => '000111',
    'D&X' => '000000',
    'D|X' => '010101',
  }

  DESTINATION_MAPPING = {
    'M' => '001',
    'D' => '010',
    'MD' => '011',
    'A' => '100',
    'AM' => '101',
    'AD' => '110',
    'AMD' => '111'
  }

  JUMP_MAPPING = {
    'JGT' => '001',
    'JEQ' => '010',
    'JGE' => '011',
    'JLT' => '100',
    'JNE' => '101',
    'JLE' => '110',
    'JMP' => '111'
  }

  def initialize(desymbolized_assembly_lines)
    @desymbolized_assembly_lines = desymbolized_assembly_lines
  end

  def self.process(lines)
    new(lines).convert_lines_to_machine_code
  end

  def convert_lines_to_machine_code
    desymbolized_assembly_lines.map do |line|
      if /@/.match(line)
        line.sub('@','').to_i.to_s(2).rjust(16,'0')
      elsif match_result = /(?<dest>.+)=(?<comp>.+);(?<jump>.+)/.match(line) # destination, computation and jump
        computation_bits = process_control_bits(match_result[:comp])
        computation_bits + DESTINATION_MAPPING[match_result[:dest]] + JUMP_MAPPING[match_result[:jump]]
      # else if theres only a destination and computation
      elsif match_result = /(?<dest>.+)=(?<comp>.+)/.match(line)
        computation_bits = process_control_bits(match_result[:comp])
        computation_bits + DESTINATION_MAPPING[match_result[:dest]] + "000"
      # else if theres only a computation and jump
      elsif match_result = /(?<comp>.+);(?<jump>.+)/.match(line)
        computation_bits = process_control_bits(match_result[:comp])
        computation_bits + "000" + JUMP_MAPPING[match_result[:jump]]
      else
        raise "unable to assemble line: #{line}"
      end
    end
  end

  def process_control_bits(comp_command)
    # find out whether the computation involves 'A' register or 'M' register
    if comp_command =~ /M/
      "1111" + COMPUTATION_MAPPING[comp_command.sub('M','X')]
    else
      "1110" + COMPUTATION_MAPPING[comp_command.sub('A','X')]
    end
  end
end

file_path = ARGV[0]
assembly_lines_without_comments_or_blanks = File.readlines(file_path).map{|line| line.split("//").first || ""}.map(&:strip).reject{|line| line == "" }
desymbolized_assembly_lines = Nand2TetrisAssemblyDesymbolizer.process(assembly_lines_without_comments_or_blanks)
hack_lines = Nand2TetrisDesymbolizedAssemblytoMachineCode.process(desymbolized_assembly_lines)
# and write those machine code lines to hack file
new_file_path = file_path.sub('.asm','.hack')
File.open(new_file_path, 'w') do |f|
  hack_lines.each do |hack_line|
    f.puts hack_line
  end
end
