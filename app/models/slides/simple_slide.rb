# frozen_string_literal: true

# ISK - A web controllable slideshow system
#
# Author::    Vesa-Pekka Palmu
# Copyright:: Copyright (c) 2012-2013 Vesa-Pekka Palmu
# License::   Licensed under GPL v3, see LICENSE.md

class SimpleSlide < SvgSlide
  TypeString = "simple"

  # Slidedata functionality
  DefaultSlidedata = {
    heading: "Slide heading",
    text: "Slide contents with <highlight>",
    color: "Red",
    text_size: 48,
    text_align: "Left"
  }.with_indifferent_access.freeze

  include HasSlidedata

  Colors = ["Gold", "Red", "Orange", "Yellow", "PaleGreen", "Aqua", "LightPink"].freeze

  validate :check_color

  # If our slidedata chances mark the slide as not ready when saving it.
  before_save do
    if @_slidedata.present? || !File.exist?(svg_filename)
      self.svg_data = SimpleSlide.create_svg(slidedata)
      self.ready = false
    end
    true
  end

  def self.copy!(s)
    orig_id = s.id

    simple = s.dup
    simple.save!
    simple.reload

    FileUtils.copy(s.svg_filename, simple.svg_filename)

    raise Slide::ConvertError unless simple.to_simple_slide!

    simple = SimpleSlide.find(simple.id)

    s = Slide.find(orig_id)
    s.replacement_id = simple.id

    return simple
  end

  # TODO: migrate to nokogiri
  def self.create_from_svg_slide(svg_slide)
    raise Slide::ConvertError unless svg_slide.is_a? SvgSlide

    simple = SimpleSlide.new
    simple.name = svg_slide.name + " (converted)"
    simple.ready = false
    simple.show_clock = svg_slide.show_clock

    svg = Nokogiri.XML(svg_slide.svg_data)

    # IF slide has other images than the background we have a problem
    raise Slide::ConvertError if svg.css("image").count != 1

    text_nodes = svg.css("text")

    # The slide needs to contain some text
    raise Slide::ConvertError unless text_nodes.count.positive?

    header = text_nodes.first.text
    text_nodes.shift

    text = +""
    text_nodes.each do |n|
      text << n.text
    end
    text.strip!

    simple.slidedata = { heading: header, text: text }
    simple.ready = false
    simple.save!

    return simple
  end

  def clone!
    new_slide = super
    new_slide.slidedata = slidedata
    return new_slide
  end

  # Take in the slide data and create a svg using them
  # This is used both to save the slide and to display a preview
  # in the simple editor page via websocket calls
  # TODO: create inkscape compliant svg!
  def self.create_svg(options)
    text_align = options[:text_align] || DefaultSlidedata[:text_align]
    text_size = options[:text_size] || DefaultSlidedata[:text_size]
    color = options[:color] || DefaultSlidedata[:color]
    heading = options[:heading] || ""
    text = options[:text] || ""

    current_event = Event.current
    settings = current_event.simple_editor_settings
    size = current_event.picture_sizes[:full]

    svg = prepare_template(settings, size, current_event.background_image)

    head = svg.at_css(HeadingSelector)
    set_text(head, heading, settings[:heading][:coordinates].first, color, settings[:heading][:font_size])

    # Find out the text x coordinate
    text_x = row_x(text_align, settings[:body][:margins])
    body = svg.at_css(BodySelector)
    set_text(body, text, text_x, color, text_size, text_align)

    return svg.to_xml
  end

private

  # Validate that the highlight color is ok
  def check_color
    # Do not run this validation if slidedata hasn't been changed or loaded, as doing so will mark the slide as not ready
    return true if @_slidedata.nil?
    errors.add :color, "is not whitelisted" unless Event.current.config[:simple][:colors].include? slidedata[:color]
  end
end
