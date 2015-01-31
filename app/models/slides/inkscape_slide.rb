# ISK - A web controllable slideshow system
#
# Author::		Vesa-Pekka Palmu
# Copyright:: Copyright (c) 2012-2013 Vesa-Pekka Palmu
# License::		Licensed under GPL v3, see LICENSE.md


class InkscapeSlide < SvgSlide

	TypeString = 'inkscape'

	EmptySVG = Rails.root.join('data','templates', 'inkscape_empty.svg')

	InkscapeFragment = Rails.root.join('data','templates', 'inkscape_settings_fragment.xml')

	before_create do |slide|
		slide.is_svg = true
		true
	end

	def self.copy!(s)
		orig_id = s.id

		ink = s.dup
		ink.save!
		ink.reload

		FileUtils.copy(s.svg_filename, ink.svg_filename)

		ink.to_inkscape_slide!

		ink = InkscapeSlide.find(ink.id)

		s = Slide.find(orig_id)
		s.replacement_id = ink.id

		return ink
	end

	# Create a new InkscapeSlide from a SimpleSlide
	def self.create_from_simple(simple_slide)
		raise ApplicationController::ConvertError unless simple_slide.is_a? SimpleSlide
		
		ink = InkscapeSlide.new
		ink.name = "#{simple_slide.name} (converted)"
		ink.description = "Converted from a simple slide #{simple_slide.name} at #{I18n.l Time.now, format: :short}"
		ink.ready = false
		ink.svg_data = simple_slide.svg_data
		ink.save!
		ink.delay.generate_images
		return ink
	end

	# We carry the slide id in a metadata tag
	# This is used by the inkscape plugins
	# TODO: verification cookie?
	# FIXME: Use a better id and sync with plugins!
	def update_metadata!
		svg = Nokogiri::XML(self.svg_data)
		svg = metadata_contents(svg)

		File.open(self.svg_filename, 'w') do |f|
			f.write svg.to_xml
		end
	end

	protected

	def metadata_contents(svg)
		svg.css('metadata').each do |meta|
			meta.remove
		end
		metadata = Nokogiri::XML::Node.new 'metadata', svg
		metadata['id'] = 'metadata1'
		meta = "#{self.id}!depricated.invalid.com"
		metadata.content = meta
		svg.root.add_child metadata
		return svg
	end

	def inkscape_modifications
		svg = REXML::Document.new(self.svg_data)

		svg.root.add_namespace('sodipodi', "http://sodipodi.sourceforge.net/DTD/sodipodi-0.dtd")
		svg.root.add_namespace('inkscape', "http://www.inkscape.org/namespaces/inkscape")

		#TODO named-view?
		inkscape_settings = REXML::Document.new(File.read(InkscapeSlide::InkscapeFragment))

		svg.root.delete_element('//sodipodi:namedview')
		svg.root[0,0] = inkscape_settings.root.elements['sodipodi:namedview']

		svg.root.elements.each('//text') do |e|
			e.delete_attribute 'xml:space'
			e.attributes['sodipodi:linespacing'] = '125%'
			e.elements.each('tspan') do |ts|
				ts.attributes['sodipodi:role'] = 'line'
			end
		end

		svg_data = svg.to_s
		svg_data.gsub!('FranklinGothicHeavy', 'Franklin Gothic Heavy')

		self.svg_data = svg_data
	end

	private
end
