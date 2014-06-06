# ISK - A web controllable slideshow system
#
# Author::		Vesa-Pekka Palmu
# Copyright:: Copyright (c) 2012-2013 Vesa-Pekka Palmu
# License::		Licensed under GPL v3, see LICENSE.md


class Presentation < ActiveRecord::Base
	#This class contains the logic for presentations
	#Presentations are made up from ordered lists
	#of master groups, containing ordered lists of slides
	

	has_many :groups, -> {order "position ASC"}
	has_many :master_groups, through: :groups
	belongs_to :effect
	belongs_to :event
	has_many :displays
	
	has_many :permissions
	has_many :authorized_users, through: :permissions, source: :user, class_name: 'User'
	#TODO: Bind presentations to events also
	
	#Validation to ensure the asigned effect actually exists in db
	validate :ensure_effect_exists
	validates :name, presence: true, length: { :maximum => 100 }
	validates :duration, presence: true, numericality: {only_integer: true, greater_than_or_equal_to: -1}
	
	before_create do |p|
		p.event = Event.current
	end
	
	# Touch associated displays
	after_save do |p|
		p.displays.each do |d|
			d.touch
		end
	end
	
	
	
	#Module that contains our ACL logic.
	include ModelAuthorization
	
	#Shorthand for returning the count of public slides
	#in the presentation
	def total_slides
		self.groups.joins(:master_group => :slides).where(:slides => {:public => true, :deleted => false, :replacement_id => nil}).count
	end
	
	#Returns a Relation that selects all slides in this presentation in order (public or not)
	def slides
		Slide.joins(:master_group => {:groups => :presentation}).where(:presentations => {:id => self.id}).order('groups.position, slides.position')
	end
	
	#Returns a Relation with all public slides in this presentation
	#The slides are in presentation order and have the group.id selected
	#as presentation_group_id so that it is accessible in the slide objects returned.
	def public_slides
		Slide.joins(:master_group => {:groups => :presentation})
			.where(:presentations => {:id => self.id}, :slides => {:public => true, :deleted => false, :replacement_id => nil})
			.order('groups.position, slides.position')
	end
	
	#Creates a hash of the presentation data
	#The has currently has two representations of the
	#slides in the presentation due to legacy
	#TODO: cache to_hash fragments
	#Rails.cache.fetch("cache_key", run_if_not_found())
	def to_hash
		hash = Rails.cache.fetch hash_cache_name, :tag => "presentation_" + self.id.to_s do
			hash = Hash.new
			hash[:name] = self.name
			hash[:id] = self.id
			hash[:effect] = self.effect_id
			hash[:created_at] = self.created_at.to_i
			hash[:updated_at] = self.updated_at.to_i
			hash[:total_groups] = self.groups.count
			hash[:total_slides] = self.total_slides
			
			hash[:slides] = Array.new
		
			#The new format for presentation slides, requires less sql-queries to build
			slides_for_hash.each do |slide|
				hash[:slides] << slide.to_hash
			end
			hash
		end
		return hash
	end
		
	# Calculate the duration of this presentation and return it in seconds.
	def duration
		default_slides_time = self.delay * self.public_slides.where(slides: {duration: Slide::UsePresentationDelay}).count
		special_slides_time = self.public_slides.where('duration != ?', Slide::UsePresentationDelay).sum('duration')
		return default_slides_time + special_slides_time
	end
	
	#Cache tag for all fragments depending on this presentation 
	def cache_tag
		"presentation_" + self.id.to_s
	end
	
	#What name to use as key for to_hash caching
	def hash_cache_name
		cache_key + "_hash"
	end
	
		
	private
	
	# Augmented select for creating the hash serialization
	def slides_for_hash
		Slide.joins(:master_group => {:groups => :presentation})
			.where(:presentations => {:id => self.id}, :slides => {:public => true, :deleted => false, :replacement_id => nil})
			.order('groups.position, slides.position')
			.select('slides.*, groups.id AS presentation_group_id, 
				master_groups.effect_id as group_effect_id,
				presentations.delay as presentation_delay,
				presentations.effect_id as presentation_effect_id,
				master_groups.name as group_name')
	end
	
			
	#Validation method for making sure the asigned effect is a valid object.
	def ensure_effect_exists
		errors.add(:effect_id, "^Transition effect is invalid") if self.effect.nil?
	end
	
	
end
