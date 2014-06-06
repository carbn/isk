# ISK - A web controllable slideshow system
#
# master_group.rb STI inherited group with a generator
# for making price ceremony slidesets
#
# Author::    Vesa-Pekka Palmu
# Copyright:: Copyright (c) 2012-2013 Vesa-Pekka Palmu
# License::   Licensed under GPL v3, see LICENSE.md


class	PrizeGroup < MasterGroup
  DefaultData = [
  	{:name => '1', :by => '', :pts => ''},
		{:name => '2', :by => '', :pts => ''},
		{:name => '3', :by => '', :pts => ''},
		{:name => '4', :by => '', :pts => ''},
		{:name => '5', :by => '', :pts => ''}
  ]  
	@_data = nil
	
	
	after_save do
		write_data
		generate_slides
	end
	
	
  def data
		return @_data if @_data.present?
    if !self.new_record? && File.exists?(data_filename)
      @_data = YAML.load(File.read(data_filename))
		end
		return @_data.blank? ? self.class::DefaultData : @_data
  end
  
  def data=(d)
    if d.nil?
			d = self.class::DefaultData
		end
	
	  @_data=d
  end
	
	def generate_slides
		@header = self.name
		@data = Array.new
		
		index = 1
		data.each do |d|
			if d[:name].present?
				@data << {:place => index.ordinalize, :name => d[:name]}
				@data << {:pts => d[:pts], :name => d[:by]}
				index += 1
			end
		end
		@entries = index - 1
		
		(index - self.slides.where(:type => InkscapeSlide.sti_name).count).times do
			slide = InkscapeSlide.new
			slide.name = self.name
			self.slides << slide
			slide.save!
		end
		
		
		self.hide_slides
		
		result_slides = self.slides.where(:type => InkscapeSlide.sti_name).to_a
		
		@data.reverse!
		
		index.times do
			slide = result_slides.last
			slide.name = @header
			self.slides << slide
			slide.publish
			slide.svg_data = template.result(binding)
			slide.save!
			slide.delay.generate_images
			@data.pop
			@data.pop
			result_slides.pop
		end	
		
	end
	
	
	
	private
	
	def template
		template = ERB.new(File.read(Rails.root.join('data', 'templates', 'prize.svg.erb')))
	end
	
	def data_filename
		if self.id
			return Rails.root.join('data', 'prizes', 'prize_group_' + self.id.to_s)
		else
			return nil
		end
	end
  
	def write_data
    unless self.new_record?
      File.open(data_filename,  'w') do |f|
        f.write self.data.to_yaml
      end
    end
  end
	
end