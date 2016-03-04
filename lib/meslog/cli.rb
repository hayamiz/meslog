# coding: utf-8

require 'json'
require 'optparse'

module Meslog
  module CLI
    class Runner
      def initialize
      end

      def run(argv)
        $progname = $0

        if argv.first == "-h" || argv.first == "--help"
          puts "TODO: show help"
        elsif argv.first == "agg"
          $cmdname = argv.shift
          return ::Meslog::Command::Agg.new.run(argv)
        end
      end
    end
  end

  class DataCell
    def initialize
      @values = []
    end

    def push_value(val)
      @values.push(val)
    end

    def avg
      @values.inject(&:+) / @values.size.to_f
    end

    def size
      @values.size
    end
  end

  module Command
    class BaseCommand
      def parse_param_path(param_path_str)
        param_path_str
      end

      def fmt_num(x)
        w = 6
        w -= (Math.log10(x)).ceil
        if w < 0
          w = 0
        end
        fmtstr = "%.#{w}f"
        sprintf(fmtstr, x)
      end

      def process_meslog(io_or_path)
        if io_or_path.is_a? String
          input = File.open(io_or_path)
        else
          input = io_or_path
        end

        records = []
        param_paths = []
        data_paths = []

        # 1st pass: extract JSON records, parameter paths, and data paths
        input.each_line do |line|
          unless line =~ /^\[MESLOG(?:\.([a-z0-9_]+))?\](.+)$/
            next
          end

          tag = $~[1]
          json = JSON.parse($~[2])

          if tag
            raise NotImplementedError.new("tag is not implemented yet.")
          end

          record = json.dup
          record["tag"] = tag

          records.push(record)

          record["params"].keys.each do |param_path|
            param_paths.push(param_path) unless param_paths.include?(param_path)
          end

          record["data"].keys.each do |data_path|
            data_paths.push(data_path) unless data_paths.include?(data_path)
          end
        end

        if records.size == 1
          return true
        end

        const_param_paths = []
        candidate_param_paths = []

        fst_record = records.first
        param_paths.each do |param_path|
          if records.all? {|record|
              fst_record["params"][param_path] == record["params"][param_path] }
            const_param_paths.push(param_path)
          else
            candidate_param_paths.push(param_path)
          end
        end

        # auto-selecting x-axis
        if @x_axis.nil?
          if candidate_param_paths.size == 0
            puts "[ERROR] no candidate for x-axis."
            exit(false)
          elsif candidate_param_paths.size > 1
            puts("[ERROR] multiple candidates for x-axis auto-selection. Specify one by --x-axis option.")
            puts("  candidates: " + candidate_param_paths.join(", "))
            exit(false)
          end

          @x_axis = candidate_param_paths.first
        end

        records = records.sort_by do |record|
          record["params"][@x_axis]
        end

        # 2nd-pass: grouping records with parameter values excluding x-axis.
        preset_param_paths = param_paths.select do |param_path|
          param_path != @x_axis
        end

        record_groups = Hash.new
        records.each do |record|
          preset_params = preset_param_paths.map do |param_path|
            record["params"][param_path]
          end

          record_groups[preset_params] ||= []
          group = record_groups[preset_params]

          group.push(record)
        end

        dataframe_list = []

        # generate dataframe for each group
        record_groups.each do |preset_params, group|
          dataframe = ::Meslog::Dataframe.new(@x_axis, data_paths)

          group.each do |record|
            x = record["params"][@x_axis]

            data_paths.each do |data_path|
              dataframe[x][data_path] ||= DataCell.new
              dataframe[x][data_path].push_value(record["data"][data_path])
            end
          end

          preset_param_paths.each do |path|
            idx = preset_param_paths.index(path)
            val = preset_params[idx]
            dataframe.preset_params[path] = val
            if const_param_paths.include?(path)
              dataframe.const_params[path] = val
            end
          end

          dataframe_list.push(dataframe)
        end

        return dataframe_list
      end
    end

    class Plot < BaseCommand
      def initialize
        @parser = OptionParser.new
        @parser.banner = <<EOS
#{$progname} agg MESLOG_FILE [options]

Options:
EOS

        @x_axis = nil
        @parser.on('-x', '--x-axis PARAM_PATH') do |param_path|
          @x_axis = parse_param_path(param_path)
        end

        @y_axis = nil
        @parser.on('-y', '--y-axis PARAM_PATH') do |param_path|
          @y_axis = parse_param_path(param_path)
        end
      end

      def run(argv)
        @parser.parse!(argv)

        if argv.size == 0
          print_help("MESLOG_FILE required.", true)
        end

        file = argv.shift

        if file == "-"
          file = $stdin
        else
          file = File.open(file)
        end

        ret = process_meslog(file)

        record_groups = ret[:record_groups]
        preset_param_paths = ret[:preset_param_paths]
        const_param_paths = ret[:const_param_paths]
        data_paths = ret[:data_paths]

        record_groups.each do |preset_params, group|

        end
      end
    end

    class Agg < BaseCommand
      def initialize
        @parser = OptionParser.new
        @parser.banner = <<EOS
#{$progname} agg MESLOG_FILE [options]

Options:
EOS

        @x_axis = nil
        @parser.on('-x', '--x-axis PARAM_PATH') do |param_path|
          @x_axis = parse_param_path(param_path)
        end
      end

      def plaintext_frame_label(dataframe)
        const_param_label = dataframe.const_params.map do |key, val|
          "#{key}: #{val}"
        end.join(", ")

        other_param_label = dataframe.preset_params.select do |key, val|
          ! dataframe.const_params.has_key?(key)
        end.map do |key, val|
          "#{key} = #{val}"
        end.join(", ")

        "#{const_param_label} || #{other_param_label}"
      end

      def run(argv)
        @parser.parse!(argv)

        if argv.size == 0
          print_help("MESLOG_FILE required.", true)
        end

        file = argv.shift

        if file == "-"
          file = $stdin
        else
          file = File.open(file)
        end

        dataframe_list = process_meslog(file)

        dataframe_list.each do |dataframe|
          frame_label = plaintext_frame_label(dataframe)

          puts("#== #{frame_label} ==")
          puts("#" + ([dataframe.axis_path, "num_records"] + dataframe.data_paths).join("\t"))
          dataframe.each do |x, data_cells|
            puts([x,
                 data_cells[dataframe.data_paths.first].size,
                  *dataframe.data_paths.map{|path|
                    fmt_num(data_cells[path].avg)
                  }].map(&:to_s).join("\t"))
          end

          puts("")
          puts("")
        end

        true
      end

      def print_help(errmsg = nil, do_exit = false)
        if errmsg
          $stderr.puts("[ERROR] #{errmsg}")
        end
        puts(@parser.help)

        exit(false) if do_exit
      end
    end
  end
end
