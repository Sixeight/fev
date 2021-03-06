#! /usr/bin/env ruby
# -"- coding: utf-8 -*-

unless defined? FEV_RUN
  require 'optparse'
  upload   = false
  password = nil
  tmp_argv = []
  remain =
    OptionParser.new {|opt|
      opt.on('-e env', 'set the environment (default production)')       {|v| tmp_argv << '-e' << v }
      opt.on('-s server', 'specify rack server/handler (default thin)')  {|v| tmp_argv << '-s' << v }
      opt.on('-p port', 'set the port (default 4567)')                   {|v| tmp_argv << '-p' << v }
      opt.on('-l', '--lock=pass', 'set the password')                    {|v| password = v          }
      opt.on('-u', '--enable-upload', 'run with uploader')               {    upload = true         }
      opt.on('-x', 'turn on the mutex lock (default off)')               {    tmp_argv << '-x'      }
    }.parse!(ARGV)

  ARGV.concat tmp_argv

  require 'rubygems'
  require 'sinatra'
  require 'haml'
  require 'sass'

  directory = remain.last
  unless directory && File.exist?(directory)
    warn "'#{directory}' doen't exist"
    exit 1
  end

  set :environment, :production unless ARGV.include?('-e')
  set :public, File.expand_path(directory)
  set :directory, directory
  set :files, lambda { Dir["#{directory}/*"].select {|f| !File.directory?(f) && !File.symlink?(f) } }
  set :total_size, lambda { files.inject(0) {|total, file| File.size(file) + total } }
  set :max_length, lambda { files.map {|e| File.basename(e).size }.max }
  set :upload, upload
  set :password, password

  enable :sessions

  FEV_RUN = true
end

not_found do
  haml "%h2 404 not found\n%p Sorry. There is no such file in this server."
end

template :layout do
  <<-'EOS'
!!! XML
!!! Strict
%html{ :xmlns => 'http://www.w3.org/1999/xhtml' }
  %head
    %meta{ :'http-equiv' => 'Content-Type', :content => 'text/html; charset=utf-8' }
    %link{ :rel => 'stylesheet', :type => 'text/css', :href => '/css/application.css' }
    %title Fev
  %body
    #header
      %h1== #{File.basename(options.public)}/
    #contents
      =yield
    #footer
      Powerd by
      %a{ :href => 'http://www.sinatrarb.com/' } Sinatra
  EOS
end

get '/css/application.css' do
  content_type 'text/css', :charset => 'utf-8'
  sass <<-EOS
html
  :font-family monospace
  :font-size 14px
h1
  :margin 0
  :margin-bottom 15px
  :font-size 35px
  :border-bottom 10px solid black
h3
  :margin-bottom 5px
  :font-weight normal
a
  :text-decoration none
  :color #333
  &:hover
    :color white
    :background-color black
span.prefix
  :padding-right 10px
  :color black
  :font-weight bold
ul
  :margin-top 0
  :margin-left 5px
  :padding 0
  li
    :margin-top 10px
    :padding-left 10px
    :list-style-type none
    :color #333
    &.even
      :background-color #ddd
    &:hover
      :margin-left -5px
      :border-left 5px solid black
    span.fname
      :display inline-block
      :width #{options.max_length}em
    span.fsize
      :display inline-block
      :width 4.5em
      :text-align right
#footer
  :margin-top 20px
  EOS
end

before do
  unless %w[ /login /css/application.css ].include? request.path_info
    redirect 'login' if options.password && !session[options.password.to_sym]
  end
end

get '/' do
  haml(<<-'EOS', :locals => { :cycle => cyclize('odd', 'even') })
- if options.upload
  #upload
    %form{ :action => '/', :method => 'post', :enctype => 'multipart/form-data' }
      %input#filename{ :name => 'file', :size => 20, :type => 'file' }
      %input{ :type => 'submit', :value => 'upload' }
#list
  %h3== in #{options.public}
  - if options.files.empty?
    %p There are no files.
  - else
    %p= "total: %d files, size: %s" % [options.files.size, humanize(options.total_size)]
    %ul
      - options.files.each do |file|
        - name = File.basename(file)
        %li{ :class => cycle.call }<
          %span.prefix> &gt;
          %span.fname>
            %a{ :href => name }>= name
          |
          %span.fsize>= humanize File.size(file)
          = " | #{humanize File.mtime(file)} |"
  EOS
end

post '/' do
  file = params[:file]
  unless File.exist? file[:filename]
    File.open(file[:filename], 'wb') do |io|
      io.write file[:tempfile].read
    end
  end
  redirect '/'
end

get '/login' do
  haml <<-EOS
#login
  %form{ :action => '/login', :method => 'post' }
    %input{ :name => 'pass' }
    %input{ :type => 'submit', :value => 'login' }
  EOS
end

post '/login' do
  unless params[:pass] == options.password
    redirect '/login'
  end
  session[options.password.to_sym] = true
  redirect '/'
end

helpers do
  def humanize(target)
    case target
    when Fixnum
      humanize_size target
    when Time
      humanize_time target
    end
  end

  def humanize_size(size)
    file_size, i =
      (0..4).inject([size, 0]) do |m, _|
        break m if m[0] < 1024.0
        [m[0] / 1024.0, m[1] + 1]
      end
    "%.1f%s" % [file_size, %w[ B KB MB GB TB ][i]]
  end

  def humanize_time(time)
    time.strftime "%b %d %H:%M"
  end

  def cyclize(*args)
    __cycle_count = -1
    lambda { args[(__cycle_count += 1) % args.size] }
  end
end

