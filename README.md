# ISK - A web controlled slideshow system
[![pipeline status](https://gitlab.com/iskcrew/isk/badges/master/pipeline.svg)](https://gitlab.com/iskcrew/isk/commits/master)[![coverage report](https://gitlab.com/iskcrew/isk/badges/master/coverage.svg)](https://gitlab.com/iskcrew/isk/-/jobs/artifacts/master/file/coverage/index.html?job=test)

System for centrally managing multiple screens running multiple presentation,
possibly sharing slides / groups of slides. Has simple online-editor and a
inkscape plugin for creating more complex slides.

## Runtime dependencies for production
Versions listed are known good ones, other versions are probably fine.

 * Unix environment (linux or os x, debian stretch recommended)
 * Imagemagick
 * Nginx (version >1.3 or some other front-end webserver capable of proxying websocket connections)
 * memcached (>= 1.4.5)
 * redis (>= 2.6.10)
 * inkscape (0.48.5-3 from jessie DOES NOT WORK)
 * postgresql (>=9.1 && <10, versions 10+ won't work with rails4)
 * rrdtool (>=1.4.7) for statistic collection and graph generation
 * nodejs for javascript runtime for asset creation

## Vagrant: Development environment the easy way

The easiest way to get the development environment up and running is to use Vagrant, a system for creating virtual machines. Install vagrant from https://www.vagrantup.com/downloads.html and then just use "vagrant up" command in the cloned ISK directory and soon you will have a virtual machine with all dependencies installed. Then just use "vagrant ssh" to connect to the virtual machine.

## Installation

To get the dev environment running you need to do the following:

1. install external dependencies
2. setup rvm and ruby
3. clone the isk git repository
4. install the rubygems needed for isk
5. create the database and initialize it

### Install the external dependencies

1. redis (debian pkg: redis-server)
2. memcached
2. Imagemagick (we use 'convert' and 'identify' imagemagick CLI tools)
3. postgresql + dev headers (postgresql postgresql-client libpq-dev)
4. inkscape
5. rrdtool, librrd + dev headers (rrdtool, librrd4, librrd-dev)
5. git
6. curl
7. nodejs

The command "apt-get install redis-server memcached imagemagick postgresql postgresql-client libpq-dev inkscape rrdtool librrd-dev git curl nodejs" should install all of the above in a debian based linux distribution.

### Rvm and rubies

It is recomended to use rvm for managing the ruby version and gems for isk development. See https://rvm.io/ for information for rvm.

To install rvm and the ruby version used by ISK:

1. \curl -sSL https://get.rvm.io | bash -s stable
2. source the rvm script file as instructed post-install
3. run "rvm requirements" and install packages as needed
4. "rvm install 2.4.1" to install ruby 2.4.1

### Clone isk git repository

Use "git clone https://gitlab.com/iskcrew/isk.git isk" to clone the repository. With rvm installed and changing to the isk repository directory with "cd" rvm will automatically select the correct ruby and gemset.

### Install the rubygems needed for isk

ISK manages its rubygem dependencies with bundler. This makes installing the correct versions of needed rubygems easy, install bundler with "gem install bundler" and the bundled gems with "bundle install" in the isk directory.

### Create the database and initialize it

You need to copy the config/database.yml.example file to config/database.yml and edit it for your database configuration. You also need to create the database in your postgresql server.

After the database exists and the database.yml file points to it you can initialize it with "rake db:setup".

### Generate the session cookie secret tokens

ISK needs to have the cookie encryption tokens in 'config/secrets.yml'. Easiest way to generate the tokens is to use the 'rake isk:secrets' command.

### Development: Start the server

Now you can start the local isk server instance with "rails s" and then navigate to http://localhost:3000/ with a browser. The default login for a new installation is username: admin password: admin.

You also need to start the background process for isk to generate the slide images. This is done by running "./isk-server.rb start resque" or "TERM_CHILD=1 BACKGROUND=yes PIDFILE=tmp/pids/resque.pid QUEUE=* rake resque:work".

For periodic tasks, like updating schedule slides there is a another background daemon you can start it with "./isk-server.rb start background_jobs" or "script/background_jobs.rb start".

### Production environment

For performance you will want to have nginx in front of ISK for serving static files (slide images mostly) for performance reasons. Example configuration for nginx can be created by "rake isk:nginx". The file will have correct directories, but you still need to update it with the servers hostname. If you can't use nginx as a front-end you need to edit config/environments/production.rb and enable serving of static assets and disable x-sendfile support.

For the default production configuration the server will expect precompiled javascript/css files, to generate them you need to run "rake assets:precompile" on the production environment.

By default the puma webserver will be run with 2 worker processes that will have at most 16 threads. It is recommended that you run one worker per processor in your production environment for maximum performance. You can modify the settings in config/puma.rb

The RAILS\_ENV environmental variable controls what environment configuration rails loads, so you also need to set it to "production". You can do this in your shells initialization files or by prepending all commands with "RAILS_ENV=production".

#### The isk-server.rb script

The isk-server.rb script is a easy way of starting/stopping all required processes. The basic usage is "./isk-server.rb start" or "-/isk-server stop" to start or stop all components. It is also possible to control individual components: "./isk-server.rb start resque". Run the script without parameters to see all options.

By default the script starts the rails web server on port 12765. You can change it by changing the WebServerPort constant in the start of the script.

# Configuration

Unfortunately a full web UI for all configuration of ISK is still work in progress. This means that you need to manage the slide background image and the base template by hand. Other configutation is managed from the web ui (admin->events->edit).

## The background image

The slide background image is located at data/slides/backgrounds/empty.png. This file should be a 1920x1080 or 1280x720 resolution PNG image that will serve as the background for all slides.

## The base svg template

ISK uses data/templates/simple.svg as the base for generating all slide svg files. This svg needs to have following elements:
 * \<text\> element with id=header, this will be used for the slide heading
 * \<text\> element with id=slide\_content, this will be use for the body of the slide
 * \<image\> element with id=background\_picture, this will be used for the slide background

The positioning and fill color of the text elements will be overridden by the per event configuration, but other attributes such as stroke color and width will remain. All other elements in the base template will be transfered to created slides as is.

# Inkscape integration

For more complex slides the best (and just about only) tool available is inkscape (http://inkscape.org). ISK includes two plugins for inkscape at inkscape/, the isk-new and isk-output. You need to place them in the inkscape extensions directory.

## Background images

By default the base svg template for slides in ISK uses a relative path for the slide background image to keep the svg document sizes as low as possible. This unfortunately causes some issues with editing the slides in inkscape. In order for inkscape to find the background image you need to place it at backgrounds/empty.png relative to the directory you open the slide svg from. For example windows with firefox and "open link with..." needs the backgrounds at %TEMP%\backgrounds\

## isk-new extension

This extension is for quickly creating new slides within inkscape. The new slides will be ungrouped and hidden after creation.

This extension can be found in the extensions -> isk -> new menu item. Activating the extension first gives you a dialog asking for the URL to your ISK server and login details. In addition there is a field for the name for the slide. Activating the extension will replace the current open inkscape document with that of the new slide.

## isk-output extension

This extension is for sending the modifications made to a slide in inkscape back to the ISK server. It can be found at extensions -> publish to -> isk menu item. It has similiar fields for the servers url and login details as the isk-new extension. Activating the extension will read the slide id from the svg metadata and then push it to the ISK server replacing the existing slides image.

# Running displays

We have now integrated the previously separate iskdpy repository. This means that to run the slideshow in a browser using webgl you simply need to point your browser to http://iskhost.example/displays/1/dpy just replace the '1' in the url with the numerical id of the display you want to run.

# Raspberry pi displays

It is possible to use a special browser in a raspberry pi as a ISK display. The environment for this is located at https://gitlab.com/iskcrew/buildroot-wpe

Buildroot will yeild a minimal environment for the special browser that will run completely on ramdisk after the initial boot process and thus never writes to the sd card. This avoids potential card corruption on unexpected powerloss. The system also has a watchdog enabled to detect lockups and reboot, running out of memory also triggers a reboot.

Configuring the environment relies on few files in the same fat partition on the sd card as the raspberry pi firmware and the kernel. The files are:
 * `hostname` hostname for the raspberry pi, this is used by avahi to respond to mDNS requests, eg. iskrpi1.local
 * `id_rsa.pub` Public key for ssh authentication. There is a ssh server running for remote access. This key can be used to log in as root. Password authentication has been disabled.
 * `ntp.conf` Configuration for ntpd. By default ntpd will connect to pool.ntp.org servers
 * `wpe.txt` This is the url where the browser will go on boot up. eg https://isk.local/displays/1/dpy?token=foobar
 * `wpe.conf` Configuration for the browser, like the timezone

The server detects raspberry pi displays on connect and tries to monitor their memory usage and temperature remotely. To do so we rely on ssh keys. Place the public key on the rasperry pi's and the private key in `config/wpe_key` file. Monitoring is done by the `script/rrd_monitor.rb` script.

The relatively low amount of memory on the raspberry is also a limiting factor on the number of slides their presentations can contain. The limit is approximately 75 slides.

# Copyright

(c) Copyright 2013 Vesa-Pekka Palmu and Niko Vähäsarja.

Python plugins for Inkscape (c) Copyright 2015 Jarkko Räsänen.

* app/assets/images/wait.gif by Jarkko Räsänen, cat photo by Vesa-Pekka Palmu
* app/assets/images/isklogo_* by Jarkko Räsänen
* app/assets/images/display_error.svg by Vesa-Pekka Palmu
* data/slides/backgrounds/empty.png by Jarkko Räsänen
* app/assets/images/ui-* from jquery themeroller
* vendor/assets/javascripts/jquery-noty* from https://github.com/needim/noty with MIT license
* vendor/assets/javascripts/jquery.timer.js from http://jchavannes.com/jquery-timer see file for license

License
-------

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
