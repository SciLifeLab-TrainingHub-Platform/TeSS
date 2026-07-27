require 'test_helper'

class OurResourcesControllerTest < ActionController::TestCase
  include Devise::Test::ControllerHelpers

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
    assert_select '.resources-stage-video iframe[src=?]',
                  'https://www.youtube.com/embed/_AQN4pqvZ3o'
    assert_select '.resources-further-learning__card', count: 6
    assert_select '.resources-further-learning__card h3', text: 'Train-the-Trainer course'
    assert_select '.resources-further-learning__card h3', text: 'Bicycle Principles for Short-form Training'
    assert_select '.resources-stage-contributors__item', count: 5
    assert_select '.resources-stage-contributors__item', text: /Kristen Schroeder/
    assert_select '.resources-stage-contributors__icon--portrait', count: 1
    assert_select '.resources-stage-contributors__item', text: /Nina Norgren/
    assert_select '.resources-stage-contributors__item', text: /Ineke Luijten/
    assert_select '.resources-stage-contributors__item', text: /Jill Jaworski/
    assert_select '.resources-stage-contributors__item', text: /Jessica Lindvall/
  end

  test 'should get plan page' do
    get :plan

    assert_response :success
    assert_select 'h1', 'Develop'
    assert_select '.resources-stage-nav__item--active .resources-stage-nav__label', text: 'Develop'
    assert_select '.resources-stage-plan__section h2', text: 'Announcing your course on the Training Portal'
    assert_select '.resources-stage-plan__media iframe[src=?]',
                  'https://www.youtube.com/embed/_AQN4pqvZ3o'
    assert_select '.resources-stage-plan__section h2', text: 'Setting up a GitHub Course Page'
    assert_select '.resources-stage-plan__section h3', text: 'See example course pages:'
    assert_select '.resources-stage-plan__button[href=?]',
                  'https://scilifelab-training.github.io/open-science/',
                  text: 'Open Science in the Swedish Context'
    assert_select '.resources-stage-plan__button[href=?]',
                  'https://scilifelab-training.github.io/BGE-HiC-course/module1.html',
                  text: 'BGE Hi-C Introductory Course'
    assert_select '.resources-stage-plan__button--disabled', count: 0
    assert_select '.resources-stage-resources h2', text: 'Related Resources:'
    assert_select '.resources-stage-resource[href=?]',
                  'https://doi.org/10.17044/scilifelab.28194329.v1',
                  text: /Resources for Course Planning/
    assert_select '.resources-stage-contributors__item', text: /Oliver Onions/
    assert_select '.resources-stage-contributors__item', text: /Ineke Luijten/
  end

  test 'should get deliver page' do
    get :deliver

    assert_response :success
    assert_select 'h1', 'Deliver'
    assert_select '.resources-stage-nav__item--active .resources-stage-nav__label', text: 'Deliver'
    assert_select '.resources-stage-deliver__tools h2', text: 'Tools for training delivery'
    assert_select '.resources-stage-deliver__tool[href=?]',
                  'https://training-certificate.serve.scilifelab.se/app/training-certificate',
                  text: /Course Certificate App/
    assert_select '.resources-stage-deliver__tool[href=?]',
                  'https://whisper-ai.serve.scilifelab.se/',
                  text: /WhisperAI/
    assert_select '.resources-stage-deliver__tool[href=?]',
                  'https://serve.scilifelab.se/docs/teaching/',
                  text: /JupyterLab, RStudio & other notebooks/
    assert_select '.resources-stage-deliver__tool[href=?]', 'https://www.menti.com/', text: /Menti/
    assert_select '.resources-stage-deliver__tool-description', text: 'Use SSO via your university login.'
    assert_select '.resources-stage-deliver__tool[href=?]', 'https://miro.com/', count: 0
    assert_select '.resources-stage-deliver__section h2', text: 'Facilitation Techniques'
    assert_select '.resources-stage-deliver__section p', text: /A successful facilitator/
    assert_select '.resources-stage-resources h2', text: 'Related Resources:'
    assert_select '.resources-stage-resource[href=?]',
                  'https://doi.org/10.17044/scilifelab.24599829.v1',
                  text: /Resources for Delivering Learning Experiences/
    assert_select '.resources-stage-resource[href=?]',
                  'https://scilifelab-training.github.io/train-the-trainer/2403/module1.html',
                  text: /Course Delivery & Teaching Practice/
    assert_select '.resources-stage-contributors__item', text: /Oliver Onions/
    assert_select '.resources-stage-contributors__item', text: /Ineke Luijten/
  end

  test 'should get pedagogic support page with the shared booking calendar' do
    get :pedagogic_support

    assert_response :success
    assert_select '[data-cal-embed][data-cal-namespace=?]', 'support-consult', count: 1
    assert_select '[data-cal-calendar][hidden]', count: 1
    assert_select 'script', text: /Cal\("init"/, count: 0
  end
end
