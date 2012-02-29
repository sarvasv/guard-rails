require 'fileutils'

module Guard
  class RailsRunner
    MAX_WAIT_COUNT = 10

    attr_reader :options

    def initialize(options)
      @options = options
    end

    def start
      kill_unmanaged_pid! if options[:force_run]
      run_rails_command!
      wait_for_pid
    end

    def stop
      if File.file?(pid_file)
        system %{kill -KILL #{File.read(pid_file).strip}}
        wait_for_no_pid if $?.exitstatus == 0
        FileUtils.rm pid_file
      end
    end

    def restart
      stop
      start
    end

    def build_rails_command
      #  Thu Mar  1 00:02:56 IST 2012, ram@sarvasv.in (ramonrails)
      #  * compatibility with rails 2.x
      #  * BDD/TDD can also help existing apps on older rails
      rails_script = 'rails s' # default script
      if ( ObjectSpace.each_object(Module).collect(&:name).include?( 'Rails::VERSION'))
        rails_script = 'script/server' if (Rails::VERSION::STRING[0..0] == '2')
      end
      rails_options = [
        '-e', options[:environment],
        '-p', options[:port],
        '--pid', pid_file
      ]

      rails_options << '-d' if options[:daemon]
      rails_options << '-u' if options[:debugger]
      rails_options << options[:server] if options[:server]

      #  * works for rails 2.x or 3.x
      %{sh -c 'cd #{Dir.pwd} && #{rails_script} #{rails_options.join(' ')} &'}
    end

    def pid_file
      File.expand_path("tmp/pids/#{options[:environment]}.pid")
    end

    def pid
      File.file?(pid_file) ? File.read(pid_file).to_i : nil
    end

    def sleep_time
      options[:timeout].to_f / MAX_WAIT_COUNT.to_f
    end

    private
    def run_rails_command!
      system build_rails_command
    end

    def has_pid?
      File.file?(pid_file)
    end

    def wait_for_pid_action
      sleep sleep_time
    end

    def kill_unmanaged_pid!
      if pid = unmanaged_pid
        system %{kill -KILL #{pid}}
        FileUtils.rm pid_file
        wait_for_no_pid
      end
    end

    def unmanaged_pid
      %x{lsof -n -i TCP:#{options[:port]}}.each_line { |line|
        if line["*:#{options[:port]} "]
          return line.split("\s")[1]
        end
      }
      nil
    end

    private
    def wait_for_pid
      wait_for_pid_loop
    end

    def wait_for_no_pid
      wait_for_pid_loop(false)
    end

    def wait_for_pid_loop(check_for_existince = true)
      count = 0
      while !(check_for_existince ? has_pid? : !has_pid?) && count < MAX_WAIT_COUNT
        wait_for_pid_action
        count += 1
      end
      !(count == MAX_WAIT_COUNT)
    end
  end
end

