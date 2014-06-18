# ISK - A web controllable slideshow system
#
# Author::		Vesa-Pekka Palmu
# Copyright:: Copyright (c) 2012-2013 Vesa-Pekka Palmu
# License::		Licensed under GPL v3, see LICENSE.md


class Group < ActiveRecord::Base
	belongs_to :master_group
	belongs_to :presentation

	include RankedModel
	ranks :position, :with_same => :presentation_id


	# Touch associated displays
	after_save :update_timestamps
	after_destroy :update_timestamps


	def to_hash
		hash = Hash.new
		hash[:name] = self.name
		hash[:id] = self.id
		hash[:master_id] = self.master_group.id
		hash[:position] = self.position
		hash[:total_slides] = self.master_group.slides.published.count
		hash[:created_at] = self.master_group.created_at.to_i
		hash[:updated_at] = self.master_group.updated_at.to_i
		hash[:slides] = Array.new
		self.public_slides.each do |s|
			hash[:slides] << s.to_hash(self.presentation.delay)
		end
		return hash

	end

	def slides
		self.master_group.slides
	end

	def displays
		Display.joins(:presentation => :groups).where(:groups => {:id => self.id}).uniq
	end


	def public_slides
		self.master_group.slides.where(:public => true)
	end

	def name
		self.master_group.name
	end

	def cache_tag
		'group_' + self.id.to_s
	end

	private

	def update_timestamps
		touch_by_presentation(self.presentation_id)
		if changed.include? 'presentation_id'
			touch_by_presentation(self.presentation_id_was)
		end
	end

	# We need to proganate timestamps down the presentation chain for
	# the dpy, as it updates it's data based on timestamps
	def touch_by_presentation(p_id)
		d = Display.joins(:presentation).where(presentations: {id: p_id})
		d.update_all("displays.updated_at = '#{Time.now.utc.to_s(:db)}'")

		Presentation.where(id: p_id).update_all(updated_at: Time.now.utc)
	end


end
