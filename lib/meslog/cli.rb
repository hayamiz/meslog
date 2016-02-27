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

      def run(argv)
        @parser.parse!(argv)

        if argv.size == 0
          print_help("MESLOG_FILE required.", true)
        end

        @meslog_file = argv.shift

        records = []
        param_paths = []
        data_paths = []

        if @meslog_file == "-"
          file = $stdin
        else
          file = File.open(@meslog_file)
        end

        # 1st pass: extract JSON records, parameter paths, and data paths
        file.each_line do |line|
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

        if @x_axis.nil?
          # auto-selecting x-axis
          candidate_param_paths = []

          fst_record = records.first
          param_paths.each do |param_path|
            (1..(records.size-1)).each do |idx|
              if fst_record["params"][param_path] != records[idx]["params"][param_path]
                candidate_param_paths.push(param_path)
                break
              end
            end
          end

          if candidate_param_paths.size == 0
            puts "[ERROR] no candidate for x-axis."
            exit(false)
          elsif candidate_param_paths.size > 1
            puts "[ERROR] multiple candidates for x-axis auto-selection. Specify one by --x-axis option."
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

        # 3rd-pass: process each group
        record_groups.each do |preset_params, group|
          dataframe = Hash.new

          group.each do |record|
            x = record["params"][@x_axis]
            dataframe[x] ||= Hash.new

            data_paths.each do |data_path|
              dataframe[x][data_path] ||= DataCell.new
              dataframe[x][data_path].push_value(record["data"][data_path])
            end
          end

          preset_desc = preset_param_paths.zip(preset_params).map do |path,param_value|
            "#{path}=#{param_value}"
          end.join(", ")

          puts "#== #{preset_desc} =="
          puts("# " + ([@x_axis, "num_records"] + data_paths).join("\t"))
          dataframe.each do |x, data_cells|
            puts([x,
                  data_cells[data_paths.first].size,
                  *data_paths.map{|path|
                    fmt_num(data_cells[path].avg)
                  }].map(&:to_s).join("\t\t"))
          end

          puts("")
          puts("")
          puts("")
        end

        true
      end

      def fmt_num(x)
        w = 6
        w -= (Math.log10(x)).ceil
        fmtstr = "%.#{w}f"
      sprintf(fmtstr, x)
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
