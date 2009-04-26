#! /usr/bin/env ruby
# -"- coding: utf-8 -*-

upload = ARGV.delete('--disable-upload')

require 'rubygems'
require 'sinatra'

directory = ARGV.last
unless directory && File.exist?(directory)
  warn "'#{directory}' doen't exist"
  exit 1
end

set :environment, :production
set :public, File.expand_path(directory)
set :files, lambda { Dir["#{directory}/*"].select {|f| !File.directory?(f) && !File.symlink?(f) } }
set :total_size, lambda { files.inject(0) {|total, file| File.size(file) + total } }
set :max_length, lambda { files.map {|e| File.basename(e).size }.max }
set :upload, upload.nil?

template :layout do
  <<-EOS
!!! Strict
%html
  %head
    %meta{ :'http-equiv' => 'Content-Type', :content => 'text/html', :charset => 'utf-8' }
    %link{ :rel => 'stylesheet', :type => 'text/css', :href => 'css/application.css' }
    %title Fev
  %body
    #header
      %h1 Fev
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
ul
  :margin-top 0
  :margin-left 5px
  :padding 0
li
  :margin-top 10px
  :padding-left 10px
  :list-style-type none
  :color #333
a
  :text-decoration none
  :color #333
a:hover
  :color white
  :background-color black
span.prefix
  :padding-right 10px
  :color black
  :font-weight bold
li.even
  :background-color #ddd
li:hover
  :margin-left -5px
  :border-left 5px solid black
li span.fname
  :display inline-block
  :width #{options.max_length}em
li span.fsize
  :display inline-block
  :width 4.5em
  :text-align right
#footer
  :margin-top 20px
  EOS
end

get '/' do
  haml(<<-'EOS', :locals => { :cycle => cyclize('odd', 'even') })
- if options.upload
  #upload
    %form{ :action => '/', :method => 'post', :enctype => 'multipart/form-data' }
      %input#filename{ :name => 'file', :size => 20, :type => 'file' }
      %input{ :type => 'submit', :value => 'upload' }
#list
  %h3= options.public
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

