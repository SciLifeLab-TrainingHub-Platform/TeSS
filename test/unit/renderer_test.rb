require 'test_helper'

class RendererTest < ActiveSupport::TestCase
  VALID_YOUTUBE_URLS = %w(https://youtu.be/abcd1234_-z?list=ABC123XYZQQQ
    http://www.youtube.com/watch?v=abcd1234_-z&feature=youtu.be
    http://youtu.be/abcd1234_-z&feature=channel
    http://www.youtube.com/ytscreeningroom?v=abcd1234_-z
    http://www.youtube.com/embed/abcd1234_-z?rel=0
    http://youtube.com/?v=abcd1234_-z&feature=channel
    http://youtube.com/?feature=channel&v=abcd1234_-z
    http://youtube.com/?vi=abcd1234_-z&feature=channel
    http://youtube.com/watch?v=abcd1234_-z&feature=channel
    http://youtube.com/watch?vi=abcd1234_-z&feature=channel
    https://www.youtube.com/v/abcd1234_-z
    https://m.youtube.com/watch?v=abcd1234_-z
    https://www.youtube.com/watch?app=desktop&v=abcd1234_-z
    https://m.youtube.com/watch?app=desktop&v=abcd1234_-z
    HTTPS://WWW.YOUTUBE.COM/watch?v=abcd1234_-z).freeze

  INVALID_YOUTUBE_URLS = %w(https://youtu.fi/abcd1234_-z?list=ABC123XYZQQQ
    http://www.boutube.com/watch?v=abcd1234_-z&feature=youtu.be
    http://elixir.be/abcd1234_-z&feature=channel
    http://www.youtube.biz/embed/abcd1234_-z?rel=0
    http://youtube.com/c/abcd1234_-z
    http://badyoutube.com/watch?v=abcd1234_-z&feature=channel
    https://www.youtube.com.baddomain/v/abcd1234_-z
    ftp://youtube.com/?v=abcd1234_-z).freeze

  setup do
    @resource = materials(:youtube_video_material)
    @renderer = Renderers::Youtube.new(@resource)
  end

  test 'extract video code' do
    VALID_YOUTUBE_URLS.each do |url|
      assert_equal 'abcd1234_-z', Renderers::Youtube.extract_video_code(url), "Failed to extract code from: #{url}"
    end

    INVALID_YOUTUBE_URLS.each do |url|
      assert_nil Renderers::Youtube.extract_video_code(url), "Wrongly extracted code from invalid URL: #{url}"
    end
  end

  test 'instance parser delegates to the canonical parser' do
    assert_equal 'abcd1234_-z', @renderer.extract_video_code(VALID_YOUTUBE_URLS.first)
  end

  test 'build embed URL' do
    assert_equal 'https://www.youtube.com/embed/abcd1234_-z',
                 Renderers::Youtube.embed_url(VALID_YOUTUBE_URLS.first)

    INVALID_YOUTUBE_URLS.each do |url|
      assert_nil Renderers::Youtube.embed_url(url), "Built embed URL from invalid URL: #{url}"
    end
  end

  test 'reject malformed URLs' do
    [nil, '', 'not a URL', 'https://youtube.com/%'].each do |url|
      assert_nil Renderers::Youtube.extract_video_code(url), "Extracted code from malformed URL: #{url.inspect}"
      assert_nil Renderers::Youtube.embed_url(url), "Built embed URL from malformed URL: #{url.inspect}"
    end
  end

  test 'can render?' do
    assert @renderer.can_render?
    refute Renderers::Youtube.new(materials(:good_material)).can_render?
    refute Renderers::Youtube.new(materials(:bad_material)).can_render?
  end

  test 'render content' do
    content = @renderer.render_content
    assert content.html_safe?
    assert content.start_with?('<iframe width="560" height="315" src="https://www.youtube.com/embed/1T_2xMTQCv4"')
    assert content.end_with?('</iframe>')
  end
end
