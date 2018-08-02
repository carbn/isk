# frozen_string_literal: true

# ISK - A web controllable slideshow system
#
# Author::    Vesa-Pekka Palmu
# Copyright:: Copyright (c) 2012-2013 Vesa-Pekka Palmu
# License::   Licensed under GPL v3, see LICENSE.md

# FIXME: REXML -> nokogiri

require "rexml/document"

class SlideTemplate < ActiveRecord::Base
  belongs_to :event
  has_many :fields, (-> { order(field_order: :asc) }), class_name: "TemplateField"
  has_many :slides, foreign_key: :foreign_object_id

  validates :name, :event, presence: true

  after_create :write_template
  before_validation :assign_to_event, on: :create

  accepts_nested_attributes_for :fields, reject_if: :reject_new_fields

  FilePath = Rails.root.join("data", "templates")

  scope :current, (-> { where deleted: false })

  include SvgManipulation

  # Load the svg in
  def template
    return @_template if @_template || new_record?
    @_template = File.read(filename) if File.exist?(filename)

    return @_template
  end

  # Set the template svg and process it
  # FIXME: Validate that new template has the same editable fields present!
  def template=(svg)
    @_template = svg
    process_svg
    write_template
  end

  # Handle a uploaded file
  def upload=(upload)
    self.template = upload.read
  end

  # Filename to store the svg template file in
  def filename
    FilePath.join "slide_template_#{id}.svg"
  end

  # We use soft-delete for templates, because hard-deleting the template will break all slides using it.
  def destroy
    self.deleted = true
    save!
  end

  def generate_svg(data)
    svg = Nokogiri::XML(template)

    fields.editable.each do |f|
      svg.css("text\##{f.element_id}").each do |e|
        size = nil
        if e.key? "font-size"
          size = e["text-size"]
        else
          style = e["style"].split(";").collect { |l| l.split(":") }
          style.each do |s|
            if s.first == "font-size"
              size = s.last.to_i
              break
            end
          end
        end
        text_x = e["x"]
        SlideTemplate.clear_childs(e)
        SlideTemplate.set_text(e, data[f.element_id.to_sym], text_x, f.color, size)
      end
    end

    return svg.to_xml
  end

private

  # Associate a new SlideTemplate to Event when it's created
  def assign_to_event
    self.event = Event.current if event.nil?
    return true
  end

  # Filter for nested parameters preventing creation of new fields
  def reject_new_fields(a)
    a[:id].blank?
  end

  # Process the uploaded svg template
  # 1. We need to set the viewBox attribute for browser-scaling to work
  # 2. Extract the <text> elements and generate the associated template_Fields from that list
  # FIXME: remove rexml in favor of nokogiri
  def process_svg
    svg = REXML::Document.new(@_template)
    svg = viewbox(svg)
    generate_settings(svg)
    @_template = svg.to_s
  end

  # Set the viewBox attribute on the base svg
  # Inkscape doesn't set this and we need it for browser previews to work
  def viewbox(svg)
    width = svg.root.attributes["width"].to_i
    height = svg.root.attributes["height"].to_i
    svg.root.attributes["viewBox"] = "0 0 #{width} #{height}"
    return svg
  end

  # Extract all text fields from the svg template
  def generate_settings(svg)
    svg.root.elements.each("//text") do |e|
      f = fields.new
      f.element_id = e.attributes["id"]
      f.default_value = REXML::XPath.match(e, ".//text()").join.strip
      f.save!
    end
  end

  # Store the template in a file
  # we use binary mode here to prevent ascii conversions..
  # FIXME: set viewBox on import, so web preview scales properly!
  def write_template
    return if new_record?
    File.open(filename, "wb") do |f|
      f.write @_template
    end
  end
end
