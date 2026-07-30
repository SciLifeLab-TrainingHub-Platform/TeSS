require 'test_helper'

class OurResourcesControllerTest < ActionController::TestCase
  include Devise::Test::ControllerHelpers

  CONTRIBUTORS = {
    kristen_schroeder: {
      name: 'Kristen Schroeder',
      image: 'kristen-resources-thumbnail',
      url: 'https://training.scilifelab.se/users/kschroeder'
    },
    nina_norgren: {
      name: 'Nina Norgren',
      image: 'nina-resources-thumbnail',
      url: 'https://training.scilifelab.se/users/ninanorgren'
    },
    ineke_luijten: {
      name: 'Ineke Luijten',
      image: 'ineke-resources-thumbnail',
      url: 'https://training.scilifelab.se/users/inekeluijten'
    },
    jill_jaworski: {
      name: 'Jill Jaworski',
      image: 'jill-resources-thumbnail',
      url: 'https://training.scilifelab.se/users/j-jaworski'
    },
    jessica_lindvall: {
      name: 'Jessica Lindvall',
      image: 'jessica-resources-thumbnail',
      url: 'https://training.scilifelab.se/about/us#team'
    }
  }.freeze

  test 'should get resources landing page' do
    get :our_resources

    assert_response :success
    assert_select 'h1', 'What stage are you at?'
    assert_select '.resources-lifecycle__card', count: 4
    assert_select '.resources-lifecycle__card h2', text: 'Plan & Design'
    assert_select '.resources-lifecycle__card h2', text: 'Develop'
    assert_select '.resources-lifecycle__card h2', text: 'Deliver'
    assert_select '.resources-lifecycle__card h2', text: 'Evaluate & Archive'
    assert_select '.resources-lifecycle__card[href=?]', plan_design_stage_path, count: 1
    assert_select '.resources-lifecycle__card[href=?]', develop_stage_path, count: 1
    assert_select '.resources-lifecycle__card[href=?]', deliver_stage_path, count: 1
    assert_select '.resources-lifecycle__card[href=?]', evaluate_archive_stage_path, count: 1
    assert_select '.resources-consultation h2', text: 'Book a consultation or apply for support'
    assert_select '[data-cal-embed][data-cal-namespace=?]', 'support-consult', count: 1
    assert_select '[data-cal-load]', count: 0
    assert_select '[data-cal-calendar][hidden]', count: 1
    assert_select '[data-cal-status][role=?]', 'status', count: 1
    assert_select '.resources-booking__fallback a[href=?]',
                  'https://cal.com/scilifelab-traininghub/support-consult',
                  text: 'Open booking page on Cal.com'
  end

  test 'should get design develop page' do
    get :design_develop

    assert_response :success
    assert_select '.breadcrumbs', count: 0
    assert_select 'title', "Plan & Design - #{TeSS::Config.site['title']}"
    assert_select 'h1', 'Plan & Design'
    assert_select '.resources-stage-nav__item--active .resources-stage-nav__label', text: 'Plan & Design'
    assert_select '.resources-stage-nav__sections[aria-label=?]', 'Plan & Design sections', count: 1
    assert_select '.resources-stage-nav__sections a', count: 3
    assert_select '.resources-stage-nav__sections a[href=?]', '#target-audience', count: 1
    assert_select '.resources-stage-nav__sections a[href=?]', '#learning-outcomes', count: 1
    assert_select '.resources-stage-nav__sections a[href=?]', '#engaging-experiences', count: 1
    assert_select '.resources-stage-section', count: 3
    assert_select '.resources-stage-section h2', text: 'Identify your target audience'
    assert_select '.resources-stage-section h2', text: 'Develop learning outcomes'
    assert_select '.resources-stage-section h2', text: 'Choose engaging learning experiences'
    assert_select 'img.resources-taxonomy__image[alt=?]',
                  "Bloom's taxonomy pyramid, from remember through understand, apply, analyze, evaluate, and create"
    assert_select 'img.resources-digital-learning__image[alt=?]',
                  "Infographic mapping digital learning activities to the six levels of Bloom's taxonomy"
    assert_select '.resources-stage-video-frame', count: 1
    assert_select '.resources-stage-video iframe[src=?]',
                  'https://www.youtube.com/embed/IWDtFrMD298'
    assert_select '.resources-further-learning__card', count: 6
    assert_select '.resources-further-learning__card h3', text: 'Train-the-Trainer course'
    assert_select '.resources-further-learning__card h3', text: 'Bicycle Principles for Short-form Training'
    assert_contributors(
      :kristen_schroeder,
      :nina_norgren,
      :ineke_luijten,
      :jill_jaworski,
      :jessica_lindvall
    )
  end

  test 'should get develop page' do
    get :develop

    assert_response :success
    assert_select '.breadcrumbs', count: 0
    assert_select 'title', "Develop - #{TeSS::Config.site['title']}"
    assert_select 'h1', 'Develop'
    assert_select '.resources-stage-page--shell.resources-stage-page--develop', count: 1
    assert_select '.resources-stage-nav__item--active .resources-stage-nav__label', text: 'Develop'
    assert_select '.resources-stage-nav__sections[aria-label=?]', 'Develop sections', count: 1
    assert_select '.resources-stage-nav__sections a', count: 4
    assert_select '.resources-stage-nav__sections a[href=?]', '#announcing-training', count: 1
    assert_select '.resources-stage-nav__sections a[href=?]', '#training-page', count: 1
    assert_select '.resources-stage-nav__sections a[href=?]', '#computational-teaching-tools', count: 1
    assert_select '.resources-stage-nav__sections a[href=?]', '#fair-training-materials', count: 1
    assert_select '.resources-stage-section', count: 4
    assert_select '.resources-stage-section h2', text: 'Announcing your training on the Training Portal'
    assert_select '.resources-stage-section h2', text: 'Setting up a training page or website'
    assert_select '.resources-stage-section h2', text: 'Computational teaching tools from SciLifeLab Serve'
    assert_select '.resources-stage-section h2', text: 'Preparing FAIR Training Materials'
    assert_select '#fair-training-materials.resources-develop__fair-materials', count: 1
    assert_select '.resources-develop__announcement-action .resources-stage-action[href=?]',
                  'https://training.scilifelab.se/events/new',
                  text: /Announce your upcoming training here/
    assert_select '.resources-develop__announcement-cta .fa-star-o', count: 1
    assert_select '.resources-stage-video iframe[src=?]',
                  'https://www.youtube.com/embed/_AQN4pqvZ3o',
                  count: 1
    assert_select '.resources-stage-video-frame--develop', count: 1
    assert_select '.resources-develop__hosting-panel', count: 1
    assert_select '.resources-develop__hosting-column', count: 2
    assert_select '.resources-develop__hosting-column h3', text: 'SciLifeLab Canvas'
    assert_select '.resources-develop__hosting-column h3', text: 'SciLifeLab Training GitHub'
    assert_select '.resources-develop__hosting-panel .resources-stage-action', count: 6
    assert_select '.resources-develop__hosting-panel .resources-stage-action[href=?]',
                  'https://github.com/SciLifeLab-Training/scilifelab-training-template/',
                  text: /GitHub Template Repository/
    assert_select '.resources-develop__hosting-panel .resources-stage-action--grape .fa-star-o',
                  count: 1
    assert_select '.resources-develop__hosting-panel .resources-stage-action--grape img.resources-stage-action__icon--github-template-star[src*=?]',
                  'github-template-star',
                  count: 1
    assert_select '.resources-develop__hosting-panel .resources-stage-action--teal .resources-stage-action__icon',
                  count: 0
    assert_select '.resources-develop__serve-actions .resources-stage-action', count: 2
    assert_select '.resources-develop__serve-actions .resources-stage-action[href=?]',
                  'https://serve.scilifelab.se/docs/teaching/',
                  text: /Guide for using SciLifeLab Serve in teaching/
    assert_select '.resources-develop__serve-actions .resources-stage-action[href=?]',
                  'https://serve.scilifelab.se/teaching/#application',
                  text: /Application form for SciLifeLab Serve notebooks/
    assert_select '.resources-stage-action[href=?]',
                  'https://docs.google.com/document/d/1QsAmQfY2pYUcQqzLh5SEOleMXfcjH8jcDjrO50jyHXM/edit?usp=sharing',
                  text: /Checklist for Training Material Metadata/
    assert_select '#fair-training-materials .resources-stage-link-list', count: 2
    assert_select '.resources-stage-link-list a[href=?]', 'https://unsplash.com/', text: /Unsplash/
    assert_select '.resources-stage-link-list a[href=?]', 'https://pixabay.com/', text: /Pixabay/
    assert_select '.resources-stage-link-list a[href=?]', 'https://canvascommons.io/', text: /Canvas Commons/
    assert_select '.resources-stage-link-list a[href=?]', 'https://obsproject.com/', text: /OBS Studio/
    assert_select '.resources-stage-link-list a[href=?]', 'https://www.blender.org/', text: /Blender/
    assert_select '.resources-further-learning__card', count: 4
    assert_select '.resources-further-learning__card h3', text: 'FAIR by design course'
    assert_select '.resources-further-learning__card h3',
                  text: 'Training Hub Resources for Course Planning'
    assert_select '.resources-further-learning__card h3',
                  text: 'Training Hub Resources for Recording Webinars'
    assert_select '.resources-further-learning__card h3', text: 'Video Training Production Guide'
    assert_select '.resources-further-learning__link[href=?]',
                  'https://doi.org/10.17044/scilifelab.28194329.v1',
                  text: /Resource Collection/
    assert_contributors :kristen_schroeder, :nina_norgren, :ineke_luijten
  end

  test 'should get deliver page' do
    get :deliver

    assert_response :success
    assert_select '.breadcrumbs', count: 0
    assert_select 'title', "Deliver - #{TeSS::Config.site['title']}"
    assert_select 'h1', 'Deliver'
    assert_select '.resources-stage-page--shell.resources-stage-page--deliver', count: 1
    assert_select '.resources-stage-nav__item--active .resources-stage-nav__label', text: 'Deliver'
    assert_select '.resources-stage-nav__sections[aria-label=?]', 'Deliver sections', count: 1
    assert_select '.resources-stage-nav__sections a', count: 3
    assert_select '.resources-stage-nav__sections a[href=?]',
                  '#facilitation-collaborative-learning',
                  count: 1
    assert_select '.resources-stage-nav__sections a[href=?]',
                  '#tools-for-training-delivery',
                  count: 1
    assert_select '.resources-stage-nav__sections a[href=?]',
                  '#feedback-forms-certificates',
                  count: 1
    assert_select '.resources-stage-section', count: 3
    assert_select '#facilitation-collaborative-learning.resources-stage-section h2',
                  text: 'Facilitation and collaborative learning'
    assert_select '#tools-for-training-delivery.resources-stage-section h2',
                  text: 'Tools for training delivery'
    assert_select '#feedback-forms-certificates.resources-stage-section h2',
                  text: 'Feedback surveys and certificates'
    assert_select '.resources-stage-section > .resources-stage-section__visual', count: 3
    assert_select '#feedback-forms-certificates .resources-stage-prose p',
                  text: /those who have fulfilled your requirements for completion/
    assert_select '#feedback-forms-certificates .resources-stage-prose a[href=?]',
                  'https://doi.org/10.17044/scilifelab.28512722',
                  text: 'Training Hub’s Resources for Evaluating Learning'
    assert_select '#feedback-forms-certificates .resources-stage-visual-link', count: 2
    assert_select '#feedback-forms-certificates .resources-stage-visual-link[href=?]',
                  'https://training-certificate.serve.scilifelab.se/app/training-certificate',
                  text: /SciLifeLab Course Certificate App/
    assert_select '#feedback-forms-certificates .resources-stage-visual-link[href=?]',
                  'https://drive.google.com/file/d/12zJK7VTe-3ISi5NrxZBrJIu2_3pmvgLL/view?usp=share_link',
                  text: /How to use Training Hub Feedback Survey Templates/
    assert_select '#feedback-forms-certificates .resources-stage-visual-link[target=?][rel=?]',
                  '_blank',
                  'noopener noreferrer',
                  count: 2
    assert_select '#feedback-forms-certificates .resources-stage-visual-link__image' \
                  '[src*=?][width=?][height=?]',
                  'fairicon-black',
                  '60',
                  '72',
                  count: 1
    assert_select '#feedback-forms-certificates .resources-stage-visual-link__image' \
                  '[src*=?][width=?][height=?]',
                  'feedback-survey-template',
                  '70',
                  '70',
                  count: 1
    assert_select '#tools-for-training-delivery .resources-stage-prose p',
                  text: /tools are available to assist in actively engaging your participants/
    assert_select '#tools-for-training-delivery a[href=?]',
                  'https://www.mentimeter.com',
                  text: 'Mentimeter'
    assert_select '#tools-for-training-delivery .resources-deliver__mentimeter-action[href=?]',
                  'https://www.mentimeter.com/auth/saml',
                  text: 'Log in to Mentimeter using SSO'
    assert_select '#tools-for-training-delivery .resources-deliver__mentimeter-action .fa-star-o',
                  count: 1
    assert_select '#tools-for-training-delivery .resources-stage-prose p',
                  text: /A few that are used regularly in SciLifeLab training are linked below:/
    assert_select '#tools-for-training-delivery .resources-stage-link-list li', count: 3
    assert_select '#tools-for-training-delivery .resources-stage-link-list a[href=?]',
                  'https://miro.com/',
                  text: 'Miro - collaborative canvases'
    assert_select '#tools-for-training-delivery .resources-stage-link-list a[href=?]',
                  'https://create.kahoot.it/page/en/make',
                  text: 'Kahoot! - quizzes'
    assert_select '#tools-for-training-delivery .resources-stage-link-list a[href=?]',
                  'https://www.slido.com/',
                  text: 'Slido - surveys, quizzes, etc.'
    assert_select '#tools-for-training-delivery .resources-stage-link-list a[target=?][rel=?]',
                  '_blank',
                  'noopener noreferrer',
                  count: 3
    assert_select '#tools-for-training-delivery .resources-stage-deliver__tool-list', count: 0
    assert_select '#facilitation-collaborative-learning p',
                  text: /Training at SciLifeLab often involves facilitating discussions/
    assert_select '#facilitation-collaborative-learning p',
                  text: 'Our basic recommendations for facilitation include:'
    assert_select '#facilitation-collaborative-learning ul li', count: 3
    assert_select '#facilitation-collaborative-learning ul li',
                  text: /between instructor and participants\./
    assert_select '#facilitation-collaborative-learning ul li',
                  text: /fruitful group discussion\./
    assert_select '#facilitation-collaborative-learning a[href=?]',
                  'https://www.scilifelab.se/code-of-conduct/',
                  text: 'SciLifeLab Code of Conduct'
    assert_select '#facilitation-collaborative-learning a[href=?]',
                  'https://figshare.scilifelab.se/ndownloader/files/52693250',
                  text: 'Training Hub’s facilitation guide'
    assert_select '#facilitation-collaborative-learning a[target=?][rel=?]',
                  '_blank',
                  'noopener noreferrer',
                  count: 2
    assert_select '#facilitation-collaborative-learning .resources-stage-illustration__image' \
                  '[src*=?][width=?][height=?][alt=?]',
                  'participants_image',
                  '340',
                  '219',
                  'Diagram showing information flowing between a presenter and participants',
                  count: 1
    assert_select '.resources-further-learning h2', text: 'Further Learning'
    assert_select '.resources-further-learning__card', count: 3
    assert_select '.resources-further-learning__card h3',
                  text: 'Resources for Delivering Learning Experiences'
    assert_select '.resources-further-learning__link[href=?]',
                  'https://doi.org/10.17044/scilifelab.24599829.v1',
                  text: 'Resource Collection'
    assert_select '.resources-further-learning__card h3',
                  text: 'Training Hub Resources for Course Planning'
    assert_select '.resources-further-learning__link[href=?]',
                  'https://doi.org/10.17044/scilifelab.28194329.v1',
                  text: 'Resource'
    assert_select '.resources-further-learning__card h3',
                  text: 'Resources for Evaluating Learning'
    assert_select '.resources-further-learning__link[href=?]',
                  'https://doi.org/10.17044/scilifelab.28512722.v1',
                  text: 'Resource Collection'
    assert_select '.resources-further-learning__link[target=?][rel=?]',
                  '_blank',
                  'noopener noreferrer',
                  count: 3
    assert_contributors :kristen_schroeder, :nina_norgren, :ineke_luijten, :jill_jaworski
  end

  test 'should get pedagogic support page with the shared booking calendar' do
    get :pedagogic_support

    assert_response :success
    assert_select '[data-cal-embed][data-cal-namespace=?]', 'support-consult', count: 1
    assert_select '[data-cal-calendar][hidden]', count: 1
    assert_select 'script', text: /Cal\("init"/, count: 0
  end

  private

  def assert_contributors(*keys)
    assert_select '.resources-stage-contributors__item', count: keys.size
    assert_select '.resources-stage-contributors__content', count: keys.size
    assert_select '.resources-stage-contributors__content[target]', count: 0
    assert_select '.resources-stage-contributors__icon--portrait', count: keys.size

    keys.each do |key|
      contributor = CONTRIBUTORS.fetch(key)

      assert_select '.resources-stage-contributors__item', text: /#{Regexp.escape(contributor[:name])}/
      assert_select '.resources-stage-contributors__content[href=?]', contributor[:url], count: 1
      assert_select '.resources-stage-contributors__icon--portrait[src*=?]', contributor[:image], count: 1
    end
  end
end
