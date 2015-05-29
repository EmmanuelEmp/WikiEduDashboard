require 'rails_helper'

user_count = 10
article_count = 19
revision_count = 214
# Dots in course titles will cause errors if routes.rb is misconfigured.
slug = 'This_university.foo/This.course_(term_2015)'
course_start = '2015-01-01'
course_end = '2015-12-31'

describe 'the course page', type: :feature do
  before do
    course = create(:course,
                    id: 1,
                    title: 'This course',
                    slug: slug,
                    start: course_start.to_date,
                    end: course_end.to_date,
                    school: 'This university',
                    term: 'term 2015',
                    listed: 1,
                    description: 'This is a great course')
    cohort = create(:cohort)
    course.cohorts << cohort

    (1..user_count).each do |i|
      create(:user,
             id: i.to_s,
             wiki_id: "Student #{i}",
             trained: i % 2)
      create(:courses_user,
             id: i.to_s,
             course_id: 1,
             user_id: i.to_s)
    end

    ratings = ['fl', 'fa', 'a', 'ga', 'b', 'c', 'start', 'stub', 'list', nil]
    (1..article_count).each do |i|
      create(:article,
             id: i.to_s,
             title: "Article #{i}",
             namespace: 0,
             rating: ratings[(i + 5) % 10])
    end

    # Add some revisions within the course dates
    (1..revision_count).each do |i|
      # Make half of the articles new ones.
      newness = (i <= article_count) ? i % 2 : 0

      create(:revision,
             id: i.to_s,
             user_id: ((i % user_count) + 1).to_s,
             article_id: ((i % article_count) + 1).to_s,
             date: '2015-03-01'.to_date,
             characters: 2,
             views: 10,
             new_article: newness)
    end

    # Add articles / revisions before the course starts and after it ends.
    create(:article,
           id: (article_count + 1).to_s,
           title: 'Before',
           namespace: 0)
    create(:article,
           id: (article_count + 2).to_s,
           title: 'After',
           namespace: 0)
    create(:revision,
           id: (revision_count + 1).to_s,
           user_id: 1,
           article_id: (article_count + 1).to_s,
           date: '2014-12-31'.to_date,
           characters: 9000,
           views: 9999,
           new_article: 1)
    create(:revision,
           id: (revision_count + 2).to_s,
           user_id: 1,
           article_id: (article_count + 2).to_s,
           date: '2016-01-01'.to_date,
           characters: 9000,
           views: 9999,
           new_article: 1)

    ArticlesCourses.update_from_revisions
    ArticlesCourses.update_all_caches
    CoursesUsers.update_all_caches
    Course.update_all_caches
  end

  before :each do
    if page.driver.is_a?(Capybara::Webkit::Driver)
      page.driver.allow_url 'fonts.googleapis.com'
      page.driver.allow_url 'maxcdn.bootstrapcdn.com'
      # page.driver.block_unknown_urls  # suppress warnings
    end
    visit "/courses/#{slug}"
  end

  describe 'header' do
    it 'should display the course title' do
      title_text = 'This course'
      expect(page.find('.title')).to have_content title_text
    end

    it 'should display course-wide statistics' do
      new_articles = (article_count / 2.to_f).ceil.to_s
      expect(page.find('#articles-created')).to have_content new_articles
      expect(page.find('#total-edits')).to have_content revision_count
      expect(page.find('#articles-edited')).to have_content article_count
      expect(page.find('#student-editors')).to have_content user_count
      expect(page.find('#trained-count')).to have_content user_count / 2
      characters = revision_count * 2
      expect(page.find('#characters-added')).to have_content characters
      expect(page.find('#view-count')).to have_content article_count * 10
    end
  end

  describe 'overview', js: true do
    it 'should display title' do
      title = 'This course'
      expect(page.find('.primary')).to have_content title
    end

    it 'should display description' do
      description = 'This is a great course'
      expect(page.find('.primary')).to have_content description
    end

    it 'should display school' do
      school = 'This university'
      expect(page.find('.sidebar')).to have_content school
    end

    it 'should display term' do
      term = 'term 2015'
      expect(page.find('.sidebar')).to have_content term
    end

    it 'should show the course dates' do
      startf = course_start.to_date.strftime('%Y-%m-%d')
      endf = course_end.to_date.strftime('%Y-%m-%d')
      expect(page.find('.sidebar')).to have_content startf
      expect(page.find('.sidebar')).to have_content endf
    end
  end

  describe 'navigation bar' do
    it 'should link to overview' do
      link = "/courses/#{slug}"
      expect(page.has_link?('', href: link)).to be true
    end

    it 'should link to timeline' do
      link = "/courses/#{slug}/timeline"
      expect(page.has_link?('', href: link)).to be true
    end

    it 'should link to activity' do
      link = "/courses/#{slug}/activity"
      expect(page.has_link?('', href: link)).to be true
    end

    it 'should link to students' do
      link = "/courses/#{slug}/students"
      expect(page.has_link?('', href: link)).to be true
    end

    it 'should link to articles' do
      link = "/courses/#{slug}/articles"
      expect(page.has_link?('', href: link)).to be true
    end
  end

  describe 'control bar' do
    it 'should allow sorting via dropdown', js: true do
      visit "/courses/#{slug}/students"
      find('select.sorts').find(:xpath, 'option[1]').select_option
      expect(page).to have_selector('.user-list__row__name.sort.asc')
      find('select.sorts').find(:xpath, 'option[2]').select_option
      expect(page).to have_selector('.user-list__row__assignee.sort.asc')
      find('select.sorts').find(:xpath, 'option[3]').select_option
      expect(page).to have_selector('.user-list__row__reviewer.sort.asc')
      find('select.sorts').find(:xpath, 'option[4]').select_option
      expect(page).to have_selector('.user-list__row__characters-ms.sort.desc')
      find('select.sorts').find(:xpath, 'option[5]').select_option
      expect(page).to have_selector('.user-list__row__characters-us.sort.desc')
    end
  end

  describe 'articles edited view' do
    it 'should display a list of articles' do
      visit "/courses/#{slug}/articles"
      rows = page.all('.article-list__row__rating').count
      # one extra .article-list__row__title element for the column header
      expect(rows).to eq(article_count + 1)
    end

    it 'should sort article by class', js: true  do
      visit "/courses/#{slug}/articles"
      # first click on the Class sorting should sort high to low
      find(:css, '.article-list__row__rating.sort').click
      first_rating = page.find(:css, 'ul.list')
                     .first('.article-list__row__rating')
      expect(first_rating).to have_content 'Featured article'
      # second click should sort from low to high
      find(:css, '.article-list__row__rating.sort').click
      new_first_rating = page.find(:css, 'ul.list')
                         .first('.article-list__row__rating')
      expect(new_first_rating).to have_content 'Unrated'
    end
  end

  describe 'manual update' do
    it 'should redirect to the course overview', js: true do
      visit "/courses/#{slug}/manual_update"
      expect(current_path).to eq("/courses/#{slug}")
    end
  end
end
