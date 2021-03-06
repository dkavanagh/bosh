# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Cli
  module Command
    class Base
      BLOBS_DIR = "blobs"
      BLOBS_INDEX_FILE = "blob_index.yml"

      attr_reader :cache, :config, :options, :work_dir
      attr_accessor :out, :usage

      def initialize(options = {})
        @options = options.dup
        @work_dir = Dir.pwd
        config_file = @options[:config] || Bosh::Cli::DEFAULT_CONFIG_PATH
        cache_dir = @options[:cache_dir] || Bosh::Cli::DEFAULT_CACHE_DIR
        @config = Config.new(config_file)
        @cache = Cache.new(cache_dir)
      end

      class << self
        attr_reader :commands

        def command(name, &block)
          @commands ||= {}
          @commands[name] = block
        end
      end

      def director
        @director ||= Bosh::Cli::Director.new(target, username, password)
      end

      def release
        return @release if @release
        check_if_release_dir
        @release = Bosh::Cli::Release.new(@work_dir)
      end

      def blob_manager
        @blob_manager ||= Bosh::Cli::BlobManager.new(release)
      end

      def blobstore
        release.blobstore
      end

      def logged_in?
        username && password
      end

      def non_interactive?
        !interactive?
      end

      def interactive?
        !options[:non_interactive]
      end

      def verbose?
        options[:verbose]
      end

      # TODO: implement it
      def dry_run?
        options[:dry_run]
      end

      def show_usage
        say("Usage: #{@usage}") if @usage
      end

      def run(namespace, action, *args)
        eval(namespace.to_s.capitalize).new(options).send(action.to_sym, *args)
      end

      def redirect(*args)
        run(*args)
        raise Bosh::Cli::GracefulExit, "redirected to %s" % [args.join(" ")]
      end

      def confirmed?(question = "Are you sure?")
        non_interactive? ||
            ask("#{question} (type 'yes' to continue): ") == "yes"
      end

      [:username, :password, :target, :deployment].each do |attr_name|
        define_method attr_name do
          config.send(attr_name)
        end
      end

      alias_method :target_url, :target

      def target_name
        config.target_name || target_url
      end

      def target_version
        config.target_version ? "Ver: " + config.target_version : ""
      end

      def full_target_name
        # TODO refactor this method
        ret = (target_name.blank? || target_name == target_url ?
            target_name : "%s (%s)" % [target_name, target_url])
        ret + " %s" % target_version if ret
      end

      ##
      # Returns whether there is currently a task running.  A wrapper for the
      # director.rb method.
      #
      # @return [Boolean] Whether there is a task currently running.
      def task_running?
        director.has_current?
      end

      ##
      # Cancels the task currently running.  A wrapper for the director.rb
      # method.
      def cancel_current_task
        director.cancel_current
      end

      protected

      def auth_required
        target_required
        err("Please log in first") unless logged_in?
      end

      def target_required
        err("Please choose target first") if target.nil?
      end

      def deployment_required
        err("Please choose deployment first") if deployment.nil?
      end

      def check_if_release_dir
        unless in_release_dir?
          err("Sorry, your current directory doesn't look " +
              "like release directory")
        end
      end

      def check_if_dirty_state
        if dirty_state?
          say("\n%s\n" % [`git status`])
          err("Your current directory has some local modifications, " +
              "please discard or commit them first")
        end
      end

      def in_release_dir?
        File.directory?("packages") &&
            File.directory?("jobs") &&
            File.directory?("src")
      end

      def dirty_state?
        `which git`
        return false unless $? == 0
        File.directory?(".git") && `git status --porcelain | wc -l`.to_i > 0
      end

      def normalize_url(url)
        url = "http://#{url}" unless url.match(/^https?/)
        URI.parse(url).to_s
      end

    end
  end
end
