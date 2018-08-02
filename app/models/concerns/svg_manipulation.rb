# frozen_string_literal: true

#
#  has_tickets.rb
#  isk
#
#  Created by Vesa-Pekka Palmu on 2014-07-13.
#  Copyright 2014 Vesa-Pekka Palmu. All rights reserved.
#

module SvgManipulation
  extend ActiveSupport::Concern

  included do
  end

  BaseTemplate = Rails.root.join("data", "templates", "simple.svg").freeze
  HeadingSelector = "text#header"
  BodySelector = "text#slide_content"
  BackgroundSelector = "image#background_picture"

  # Define class methods for the model including this
  module ClassMethods
    # Prepare the base template based on event config
    def prepare_template(settings, size, background_image)
      svg = Nokogiri::XML(File.open(BaseTemplate))

      # Add sodipodi namespace
      svg.root.add_namespace "sodipodi", "http://sodipodi.sourceforge.net/DTD/sodipodi-0.dtd"

      # Set dimensions
      svg.root["width"] = size.first
      svg.root["height"] = size.last

      # Set viewbox
      svg.root["viewBox"] = "0 0 #{size.first} #{size.last}"

      # Set background
      bg = svg.at_css(BackgroundSelector)
      bg["xlink:href"] = background_image
      bg["x"] = 0
      bg["y"] = 0
      bg["width"] = size.first
      bg["height"] = size.last

      # Position header
      header = svg.at_css(HeadingSelector)
      header["x"] = settings[:heading][:coordinates].first
      header["y"] = settings[:heading][:coordinates].last

      # Header font size
      header["font-size"] = settings[:heading][:font_size]

      # Position body
      body = svg.at_css(BodySelector)
      body["y"] = settings[:body][:y_coordinate]

      # Clear child elements from header and body
      clear_childs(header)
      clear_childs(body)

      # Set guides
      named_view = svg.at_css("sodipodi|namedview")
      named_view.css("sodipodi|guide").each(&:remove)

      # Vertical guides
      [
        "#{settings[:body][:margins].first},0",
        "#{settings[:body][:margins].last},0",
        "#{settings[:heading][:coordinates].first},0"
      ].each do |coord|
        named_view.add_child(create_guide(svg, coord, "-200,0"))
      end

      # Horizontal guides
      [
        "0,#{size.last - settings[:body][:y_coordinate]}",
        "0,#{size.last - settings[:heading][:coordinates].last}"
      ].each do |coord|
        named_view.add_child(create_guide(svg, coord, "0,-200"))
      end

      return svg
    end

    # Create a new sodipodi:guide element
    def create_guide(svg, position, orientation)
      guide = Nokogiri::XML::Node.new("sodipodi:guide", svg)
      guide["position"] = position
      guide["orientation"] = orientation
      return guide
    end

    def set_text(element, text, text_x, color = nil, size = nil, align = nil)
      # Set default attributes
      element["x"] = text_x
      element["sodipodi:linespacing"] = "100%"
      if size
        element["font-size"] = size
      else
        size = element["font-size"]
      end
      row_y = element["y"].to_f

      first_line = true

      text.each_line do |l|
        row = Nokogiri::XML::Node.new "tspan", element
        row["sodipodi:role"] = "line"
        row["xml:space"] = "preserve"
        row["font-size"] = size
        row["x"] = text_x

        # Set the line spacing. First line has no spacing, others have 1em spacing.
        if first_line
          first_line = false
        else
          row["y"] = row_y
        end
        if l.strip.empty?
          row["font-size"] = (size.to_i * 0.4).to_i
          row["fill-opacity"] = 0
          row["stroke-opacity"] = 0
          row.content = "a"
          element.add_child row
          next
        end
        parts = l.split(/<([^>]*)>/)
        parts.each_index do |i|
          ts = Nokogiri::XML::Node.new "tspan", row
          ts["fill"] = color if color && i.odd?
          ts.content = parts[i].chomp
          row.add_child ts
        end
        element.add_child row
        row_y += size.to_f
      end

      return set_text_anchor(element, align)
    end

    def row_x(align, margins)
      return margins.first unless align

      case align.strip.downcase
      when "right"
        return margins.last
      when "centered"
        return (margins.first + margins.last) / 2
      else
        return margins.first
      end
    end

    # Clear child elements
    def clear_childs(e)
      # Clear child elements (delete_element deletes only one element)
      e.children.each(&:remove)
      e.content = ""

      return e
    end

    def set_text_anchor(element, align)
      if align
        case align.strip.downcase
        when "right"
          text_anchor = "end"
        when "centered"
          text_anchor = "middle"
        else
          text_anchor = "start"
        end
        element["text-anchor"] = text_anchor
      end
      return element
    end
  end
end
