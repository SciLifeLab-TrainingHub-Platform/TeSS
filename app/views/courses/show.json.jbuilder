# app/views/courses/show.json.jbuilder

json.extract! @course,
              :id,
              :title,
              :description,
              :language,
              :keywords,
              :authors,
              :contributors,
              :url,
              :learning_outcomes,
              :structure_and_duration,
              :target_audience,
              :prerequisites_knowledge,
              :prerequisites_technical,
              :licence,
              :slug

# Include associated nodes if present
if @course.respond_to?(:nodes)
  json.nodes @course.nodes do |node|
    json.extract! node,
                  :id,
                  :name,
                  :slug
  end
end

# Include associated events if present
if @course.respond_to?(:events)
  json.events @course.events do |event|
    json.extract! event,
                  :id,
                  :title,
                  :description,
                  :start_date,
                  :end_date,
                  :url
  end
end

# Include content providers if present
if @course.respond_to?(:content_providers)
  json.content_providers @course.content_providers do |provider|
    json.extract! provider,
                  :id,
                  :title,
                  :description,
                  :url
  end
end
