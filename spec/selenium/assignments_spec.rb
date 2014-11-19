﻿require File.expand_path(File.dirname(__FILE__) + '/common')

describe "assignments" do

  # note: due date testing can be found in assignments_overrides_spec

  include_examples "in-process server selenium tests"

  context "as a teacher" do

    def manually_create_assignment(assignment_title = 'new assignment')
      get "/courses/#{@course.id}/assignments"
      f('#right-side .add_assignment_link').click
      wait_for_ajaximations
      replace_content(f('#assignment_title'), assignment_title)
      expect_new_page_load { f('.more_options_link').click }
      wait_for_ajaximations
    end

    def submit_assignment_form
      expect_new_page_load { f('.btn-primary[type=submit]').click }
      wait_for_ajaximations
    end

    def edit_assignment
      expect_new_page_load { f('.edit_assignment_link').click }
      wait_for_ajaximations
    end

    def run_assignment_edit(assignment)
      get "/courses/#{@course.id}/assignments/#{assignment.id}/edit"

      yield

      submit_assignment_form
    end

    def stub_freezer_plugin(frozen_atts = nil)
      frozen_atts ||= {
          "assignment_group_id" => "true"
      }
      PluginSetting.stubs(:settings_for_plugin).returns(frozen_atts)
    end

    def frozen_assignment(group)
      group ||= @course.assignment_groups.first
      assign = @course.assignments.create!(
          :name => "frozen",
          :due_at => Time.now.utc + 2.days,
          :assignment_group => group,
          :freeze_on_copy => true
      )
      assign.copied = true
      assign.save!
      assign
    end

    before(:each) do
      course_with_teacher_logged_in
    end

    it "should edit an assignment" do
      assignment_name = 'first test assignment'
      due_date = Time.now.utc + 2.days
      group = @course.assignment_groups.create!(:name => "default")
      second_group = @course.assignment_groups.create!(:name => "second default")
      @assignment = @course.assignments.create!(
          :name => assignment_name,
          :due_at => due_date,
          :assignment_group => group,
          :unlock_at => due_date - 1.day
      )

      get "/courses/#{@course.id}/assignments/#{@assignment.id}/edit"
      wait_for_ajaximations

      expect(f('#assignment_group_id')).to be_displayed
      click_option('#assignment_group_id', second_group.name)
      click_option('#assignment_grading_type', 'Letter Grade')

      #check grading levels dialog
      f('.edit_letter_grades_link').click
      wait_for_ajaximations
      expect(f('#edit_letter_grades_form')).to be_displayed
      close_visible_dialog

      #check peer reviews option
      form = f("#edit_assignment_form")
      assignment_points_possible = f("#assignment_points_possible")
      replace_content(assignment_points_possible, "5")
      form.find_element(:css, '#assignment_peer_reviews').click
      wait_for_ajaximations
      form.find_element(:css, '#assignment_automatic_peer_reviews').click
      wait_for_ajaximations
      f('#assignment_peer_review_count').send_keys('2')
      driver.execute_script "$('#assignment_peer_reviews_assign_at + .ui-datepicker-trigger').click()"
      wait_for_ajaximations
      datepicker = datepicker_next
      datepicker.find_element(:css, '.ui-datepicker-ok').click
      wait_for_ajaximations
      f('#assignment_name').send_keys(' edit')

      #save changes
      submit_assignment_form
      expect(driver.execute_script("return document.title")).to include_text(assignment_name + ' edit')
    end

    it "should display assignment on calendar and link to assignment" do
      assignment_name = 'first assignment'
      due_date = Time.now + 2.days
      @assignment = @course.assignments.create(:name => assignment_name, :due_at => due_date)

      get "/calendar2#view_name=month&view_start=#{due_date.to_date.to_s}"

      wait_for_ajaximations
      f('.assignment').click
      wait_for_ajaximations
      f('.edit_event_link').click
      wait_for_ajaximations
      f('.more_options_link').click
      wait_for_ajaximations
      expect(f('#assignment_name')['value']).to include_text(assignment_name)
    end

    it "should create an assignment" do
      assignment_name = 'first assignment'
      @course.assignment_groups.create!(:name => "first group")
      @course.assignment_groups.create!(:name => "second group")
      get "/courses/#{@course.id}/assignments"

      #create assignment
      click_option('#right-side select.assignment_groups_select', 'second group')
      f('#right-side .add_assignment_link').click
      wait_for_ajaximations
      f('#assignment_title').send_keys(assignment_name)
      f('.ui-datepicker-trigger').click
      wait_for_ajaximations
      datepicker = datepicker_next
      datepicker.find_element(:css, '.ui-datepicker-ok').click
      wait_for_ajaximations
      submit_form('#add_assignment_form')

      #make sure assignment was added to correct assignment group
      wait_for_ajaximations
      keep_trying_until do
        first_group = f('#groups .assignment_group:nth-child(2)')
        expect(first_group).to include_text('second group')
        expect(first_group).to include_text(assignment_name)
      end

      #click on assignment link
      f("#assignment_#{Assignment.last.id} .title").click
      wait_for_ajaximations
      expect(f('h1.title')).to include_text(assignment_name)
    end

    %w(points percent pass_fail letter_grade gpa_scale).each do |grading_option|
      it "should create assignment with #{grading_option} grading option" do
        assignment_title = 'grading options assignment'
        manually_create_assignment(assignment_title)
        wait_for_ajaximations
        click_option('#assignment_grading_type', grading_option, :value)
        if grading_option == "percent"
          replace_content f('#assignment_points_possible'), ('1')
        end
        click_option('#assignment_submission_type', 'No Submission')
        assignment_points_possible = f("#assignment_points_possible")
        replace_content(assignment_points_possible, "5")
        submit_assignment_form
        expect(f('.title')).to include_text(assignment_title)
        expect(Assignment.find_by_title(assignment_title).grading_type).to eq grading_option
      end
    end

    it "only allows an assignment editor to edit points and title if assignment " +
           "if assignment has multiple due dates" do
      middle_number = '15'
      expected_date = (Time.now - 1.month).strftime("%b #{middle_number}")
      @assignment = @course.assignments.create!(
          :title => "VDD Test Assignment",
          :due_at => expected_date
      )
      @assignment.any_instantiation.expects(:overridden_for).at_least_once.
          returns @assignment
      @assignment.any_instantiation.expects(:multiple_due_dates?).at_least_once.
          returns true
      get "/courses/#{@course.id}/assignments"
      wait_for_ajaximations
      driver.execute_script "$('.edit_assignment_link').first().hover().click()"
      # Assert input element is hidden to the user, but still present in the
      # form so the due date doesn't get changed to no due date.
      expect(fj('.add_assignment_form .input-append').attribute('style')).
          to include 'display: none;'
      expect(f('.vdd_no_edit').text).
          to eq I18n.t("#assignments.multiple_due_dates", "Multiple Due Dates")
      assignment_title = f("#assignment_title")
      assignment_points_possible = f("#assignment_points_possible")
      replace_content(assignment_title, "VDD Test Assignment Updated")
      replace_content(assignment_points_possible, "100")
      f("#add_assignment_form").submit
      wait_for_ajaximations
      expect(@assignment.reload.points_possible).to eq 100
      expect(@assignment.title).to eq "VDD Test Assignment Updated"
      # Assert the time didn't change
      expect(@assignment.due_at.strftime('%b %d')).to eq expected_date
    end

    it "should create an assignment with more options" do
      enable_cache do
        expected_text = "Assignment 1"

        get "/courses/#{@course.id}/assignments"
        group = @course.assignment_groups.first
        AssignmentGroup.where(:id => group).update_all(:updated_at => 1.hour.ago)
        first_stamp = group.reload.updated_at.to_i
        f('#right-side .add_assignment_link').click
        wait_for_ajaximations
        expect_new_page_load { f('.more_options_link').click }
        click_option('#assignment_submission_type', 'No Submission')
        assignment_points_possible = f("#assignment_points_possible")
        replace_content(assignment_points_possible, "5")
        submit_assignment_form
        expect(@course.assignments.count).to eq 1
        get "/courses/#{@course.id}/assignments"
        expect(f('.no_assignments_message')).not_to be_displayed
        expect(f('#groups')).to include_text(expected_text)
        group.reload
        expect(group.updated_at.to_i).not_to eq first_stamp
      end
    end

    it "should verify that self sign-up link works in more options" do
      get "/courses/#{@course.id}/assignments"
      f('#right-side .add_assignment_link').click
      expect_new_page_load { f('.more_options_link').click }
      wait_for_ajaximations
      f('#has_group_category').click
      wait_for_ajaximations
      click_option('#assignment_group_category_id', 'new', :value)
      fj('.ui-dialog:visible .self_signup_help_link img').click
      wait_for_ajaximations
      expect(f('#self_signup_help_dialog')).to be_displayed
    end


    it "should validate that a group category is selected" do
      assignment_name = 'first test assignment'
      @assignment = @course.assignments.create({
                                                   :name => assignment_name,
                                                   :assignment_group => @course.assignment_groups.create!(:name => "default")
                                               })

      get "/courses/#{@course.id}/assignments/#{@assignment.id}/edit"
      f('#has_group_category').click
      close_visible_dialog
      f('.btn-primary[type=submit]').click
      wait_for_ajaximations

      errorBoxes = driver.execute_script("return $('.errorBox').filter('[id!=error_box_template]').toArray();")
      visBoxes, hidBoxes = errorBoxes.partition { |eb| eb.displayed? }
      expect(visBoxes.first.text).to eq "Please select a group set for this assignment"
    end

    it "should create an assignment with more options" do
      enable_cache do
        expected_text = "Assignment 1"

        get "/courses/#{@course.id}/assignments"
        group = @course.assignment_groups.first
        AssignmentGroup.where(:id => group).update_all(:updated_at => 1.hour.ago)
        first_stamp = group.reload.updated_at.to_i
        f('#right-side .add_assignment_link').click
        wait_for_ajaximations
        expect_new_page_load { f('.more_options_link').click }
        click_option('#assignment_submission_type', 'No Submission')
        submit_assignment_form
        expect(@course.assignments.count).to eq 1
        get "/courses/#{@course.id}/assignments"
        expect(f('.no_assignments_message')).not_to be_displayed
        expect(f('#groups')).to include_text(expected_text)
        group.reload
        expect(group.updated_at.to_i).not_to eq first_stamp
      end
    end

    def point_validation
      assignment_name = 'first test assignment'
      @assignment = @course.assignments.create({
                                                   :name => assignment_name,
                                                   :assignment_group => @course.assignment_groups.create!(:name => "default")
                                               })

      get "/courses/#{@course.id}/assignments/#{@assignment.id}/edit"
      yield if block_given?
      f('.btn-primary[type=submit]').click
      wait_for_ajaximations
      expect(fj('.error_text div').text).to eq "Points possible must be more than 0 for selected grading type"
    end

    it "should validate points for percentage grading (> 0)" do
      point_validation {
        click_option('#assignment_grading_type', 'Percentage')
      }
    end

    it "should validate points for percentage grading (!= '')" do
      point_validation {
        click_option('#assignment_grading_type', 'Percentage')
        replace_content f('#assignment_points_possible'), ('')
      }
    end

    it "should validate points for percentage grading (digits only)" do
      point_validation {
        click_option('#assignment_grading_type', 'Percentage')
        replace_content f('#assignment_points_possible'), ('taco')
      }
    end

    it "should validate points for letter grading (> 0)" do
      point_validation {
        click_option('#assignment_grading_type', 'Letter Grade')
      }
    end

    it "should validate points for letter grading (!= '')" do
      point_validation {
        click_option('#assignment_grading_type', 'Letter Grade')
        replace_content f('#assignment_points_possible'), ('')
      }
    end

    it "should validate points for letter grading (digits only)" do
      point_validation {
        click_option('#assignment_grading_type', 'Letter Grade')
        replace_content f('#assignment_points_possible'), ('taco')
      }
    end

    it "should validate points for GPA scale grading (> 0)" do
      point_validation {
        click_option('#assignment_grading_type', 'GPA Scale')
      }
    end

    it "should validate points for GPA scale grading (!= '')" do
      point_validation {
        click_option('#assignment_grading_type', 'GPA Scale')
        replace_content f('#assignment_points_possible'), ('')
      }
    end

    it "should validate points for GPA scale grading (digits only)" do
      point_validation {
        click_option('#assignment_grading_type', 'GPA Scale')
        replace_content f('#assignment_points_possible'), ('taco')
      }
    end

    context "frozen assignment", :priority => "2" do
      before do
        stub_freezer_plugin Hash[Assignment::FREEZABLE_ATTRIBUTES.map { |a| [a, "true"] }]
        default_group = @course.assignment_groups.create!(:name => "default")
        @frozen_assign = frozen_assignment(default_group)
      end

      it "should allow editing the due date even if completely frozen" do
        old_due_at = @frozen_assign.due_at
        run_assignment_edit(@frozen_assign) do
          replace_content(fj('.due-date-overrides form:first input[name=due_at]'), 'Sep 20, 2012')
        end

        expect(f('.assignment_dates').text).to match /Sep 20, 2012/
        #some sort of time zone issue is occurring with Sep 20, 2012 - it rolls back a day and an hour locally.
        expect(@frozen_assign.reload.due_at.to_i).not_to eq old_due_at.to_i
      end
    end

    context "frozen assignment_group_id" do
      before do
        stub_freezer_plugin
        default_group = @course.assignment_groups.create!(:name => "default")
        @frozen_assign = frozen_assignment(default_group)
      end

      it "should not allow assignment group to be deleted by teacher if assignment group id frozen", :priority => "2" do
        get "/courses/#{@course.id}/assignments"
        expect(fj("#group_#{@frozen_assign.assignment_group_id} .delete_group_link")).to be_nil
        expect(fj("#assignment_#{@frozen_assign.id} .delete_assignment_link")).to be_nil
      end

      it "should not be locked for admin", :priority => "2" do
        @course.assignment_groups.create!(:name => "other")
        course_with_admin_logged_in(:course => @course, :name => "admin user")
        orig_title = @frozen_assign.title

        run_assignment_edit(@frozen_assign) do
          # title isn't locked, should allow editing
          f('#assignment_name').send_keys(' edit')

          expect(f('#assignment_group_id').attribute('disabled')).to be_nil
          expect(f('#assignment_peer_reviews').attribute('disabled')).to be_nil
          expect(f('#assignment_description').attribute('disabled')).to be_nil
          click_option('#assignment_group_id', "other")
        end

        expect(f('h2.title')).to include_text(orig_title + ' edit')
        expect(@frozen_assign.reload.assignment_group.name).to eq "other"
      end

      it "should not allow assignment group to be deleted by teacher if assignment group id frozen" do
        get "/courses/#{@course.id}/assignments"
        expect(fj("#group_#{@frozen_assign.assignment_group_id} .delete_group_link")).to be_nil
        expect(fj("#assignment_#{@frozen_assign.id} .delete_assignment_link")).to be_nil
      end

      it "should not be locked for admin" do
        @course.assignment_groups.create!(:name => "other")
        course_with_admin_logged_in(:course => @course, :name => "admin user")
        orig_title = @frozen_assign.title

        run_assignment_edit(@frozen_assign) do
          # title isn't locked, should allow editing
          f('#assignment_name').send_keys(' edit')

          expect(f('#assignment_group_id').attribute('disabled')).to be_nil
          expect(f('#assignment_peer_reviews').attribute('disabled')).to be_nil
          expect(f('#assignment_description').attribute('disabled')).to be_nil
          click_option('#assignment_group_id', "other")
        end

        expect(f('h1.title')).to include_text(orig_title + ' edit')
        expect(@frozen_assign.reload.assignment_group.name).to eq "other"
      end
    end

    context "draft state" do
      before do
        @course.root_account.enable_feature!(:draft_state)
        @course.require_assignment_group
      end

      it "should create a new assignment group" do
        get "/courses/#{@course.id}/assignments"
        wait_for_ajaximations

        f("#addGroup").click
        wait_for_ajaximations

        replace_content(f("#ag_new_name"), "Second AG")
        fj('.create_group:visible').click
        wait_for_ajaximations

        expect(ff('.assignment_group .ig-header h2').map(&:text)).to include("Second AG")
      end    
 
      it "should go to the new assignment page from 'Add Assignment'", :priority => "2" do
        get "/courses/#{@course.id}/assignments"
        expect_new_page_load { f('.new_assignment').click }
        wait_for_ajaximations

        expect(f('#edit_assignment_form')).to be_present
      end

      it "should allow quick-adding an assignment to a group", :priority => "2" do
        ag = @course.assignment_groups.first

        get "/courses/#{@course.id}/assignments"
        wait_for_ajaximations

        f("#assignment_group_#{ag.id} .add_assignment").click
        wait_for_ajaximations

        replace_content(f("#ag_#{ag.id}_assignment_name"), "Do this")
        replace_content(f("#ag_#{ag.id}_assignment_points"), "13")
        fj('.create_assignment:visible').click
        wait_for_ajaximations

        a = ag.reload.assignments.first
        expect(a.name).to eq "Do this"
        expect(a.points_possible).to eq 13

        expect(f("#assignment_group_#{ag.id} .ig-title").text).to match "Do this"
      end

      it "should allow quick-adding two assignments to a group (dealing with form re-render)", :priority => "2" do
        ag = @course.assignment_groups.first

        get "/courses/#{@course.id}/assignments"
        wait_for_ajaximations

        f("#assignment_group_#{ag.id} .add_assignment").click
        wait_for_ajaximations

        replace_content(f("#ag_#{ag.id}_assignment_name"), "Do this")
        replace_content(f("#ag_#{ag.id}_assignment_points"), "13")
        fj('.create_assignment:visible').click
        wait_for_ajaximations

        keep_trying_until do
          fj("#assignment_group_#{ag.id} .add_assignment").click
          wait_for_ajaximations
          fj("#ag_#{ag.id}_assignment_name").displayed?
        end

        expect(get_value("#ag_#{ag.id}_assignment_name")).to eq ""
        expect(get_value("#ag_#{ag.id}_assignment_points")).to eq "0"

        replace_content(fj("#ag_#{ag.id}_assignment_name"), "Another")
        replace_content(fj("#ag_#{ag.id}_assignment_points"), "3")
        fj('.create_assignment:visible').click
        wait_for_ajaximations

        expect(ag.reload.assignments.count).to eq 2
      end

      #Per selenium guidelines, we should not test buttons navigating to a page
      # We could test that the page loads with the correct info from the params elsewhere
      it "should remember entered settings when 'more options' is pressed" do
        ag2 = @course.assignment_groups.create!(:name => "blah")

        get "/courses/#{@course.id}/assignments"
        wait_for_ajaximations

        f("#assignment_group_#{ag2.id} .add_assignment").click
        wait_for_ajaximations

        replace_content(f("#ag_#{ag2.id}_assignment_name"), "Do this")
        replace_content(f("#ag_#{ag2.id}_assignment_points"), "13")
        expect_new_page_load { fj('.more_options:visible').click }

        expect(get_value("#assignment_name")).to eq "Do this"
        expect(get_value("#assignment_points_possible")).to eq "13"
        expect(get_value("#assignment_group_id")).to eq ag2.id.to_s
      end

      # This should be part of a spec that follows a critical path through
      #  the draft state index page, but does not need to be a lone wolf
      it "should delete assignments" do
        ag = @course.assignment_groups.first
        as = @course.assignments.create({:assignment_group => ag})

        get "/courses/#{@course.id}/assignments"
        wait_for_ajaximations

        f("#assignment_#{as.id} .al-trigger").click
        wait_for_ajaximations
        f("#assignment_#{as.id} .delete_assignment").click

        accept_alert
        wait_for_ajaximations
        expect(element_exists("#assignment_#{as.id}")).to be_falsey

        as.reload
        expect(as.workflow_state).to eq 'deleted'
      end

      it "should reorder assignments with drag and drop" do
        ag = @course.assignment_groups.first
        as = []
        4.times do |i|
          as << @course.assignments.create!(:name => "assignment_#{i}", :assignment_group => ag)
        end
        expect(as.collect(&:position)).to eq [1, 2, 3, 4]

        get "/courses/#{@course.id}/assignments"
        wait_for_ajaximations
        drag_with_js("#assignment_#{as[0].id}", 0, 50)
        wait_for_ajaximations

        as.each { |a| a.reload }
        expect(as.collect(&:position)).to eq [2, 1, 3, 4]
      end

      context "with modules" do
        before do
          @module = @course.context_modules.create!(:name => "module 1")
          @assignment = @course.assignments.create!(:name => 'assignment 1')
          @a2 = @course.assignments.create!(:name => 'assignment 2')
          @a3 = @course.assignments.create!(:name => 'assignment 3')
          @module.add_item :type => 'assignment', :id => @assignment.id
          @module.add_item :type => 'assignment', :id => @a2.id
          @module.add_item :type => 'assignment', :id => @a3.id
        end

        it "should show the new modules sequence footer" do
          get "/courses/#{@course.id}/assignments/#{@a2.id}"
          wait_for_ajaximations
          expect(f("#sequence_footer .module-sequence-footer")).to be_present
        end
      end

      context "frozen assignment_group_id", :priority => "2" do
        before do
          stub_freezer_plugin
          default_group = @course.assignment_groups.create!(:name => "default")
          @frozen_assign = frozen_assignment(default_group)
        end
        it "should not allow assignment group to be deleted by teacher if assignments are frozen" do
          get "/courses/#{@course.id}/assignments"
          fj("#ag_#{@frozen_assign.assignment_group_id}_manage_link").click
          wait_for_ajaximations
          expect(element_exists("div#assignment_group_#{@frozen_assign.assignment_group_id} a.delete_group")).to be_falsey
        end

        it "should not allow deleting a frozen assignment from index page" do
          get "/courses/#{@course.id}/assignments"
          fj("div#assignment_#{@frozen_assign.id} a.al-trigger").click
          wait_for_ajaximations
          expect(element_exists("div#assignment_#{@frozen_assign.id} a.delete_assignment:visible")).to be_falsey
        end
      end

      context 'publishing' do
        before do
          ag = @course.assignment_groups.first
          @assignment = ag.assignments.create! :context => @course, :title => 'to publish'
          @assignment.unpublish
        end

        it "should allow publishing from the index page", :priority => "2" do
          get "/courses/#{@course.id}/assignments"
          wait_for_ajaximations
          f("#assignment_#{@assignment.id} .publish-icon").click
          wait_for_ajaximations
          expect(@assignment.reload).to be_published
          keep_trying_until { expect(f("#assignment_#{@assignment.id} .publish-icon").attribute('aria-label')).to include_text("Published") }
        end

        it "shows submission scores for students on index page" do
          @assignment.update_attributes(points_possible: 15)
          @assignment.publish
          course_with_student_logged_in(active_all: true, course: @course)
          @assignment.grade_student(@student, grade: 14)
          get "/courses/#{@course.id}/assignments"
          wait_for_ajaximations
          expect(f("#assignment_#{@assignment.id} .js-score .non-screenreader").
              text).to match "14/15 pts"
        end

        it "should allow publishing from the show page" do
          get "/courses/#{@course.id}/assignments/#{@assignment.id}"
          wait_for_ajaximations

          def speedgrader_hidden?
            driver.execute_script(
                "return $('#assignment-speedgrader-link').hasClass('hidden')"
            )
          end

          expect(speedgrader_hidden?).to eq true

          f("#assignment_publish_button").click
          wait_for_ajaximations

          expect(@assignment.reload).to be_published
          expect(f("#assignment_publish_button").text).to match "Published"
          expect(speedgrader_hidden?).to eq false
        end

        it "should show publishing status on the edit page" do
          get "/courses/#{@course.id}/assignments/#{@assignment.id}/edit"
          wait_for_ajaximations

          expect(f("#edit_assignment_header").text).to match "Not Published"
        end

        context 'with overrides' do
          before do
            @course.course_sections.create! :name => "HI"
            @assignment.assignment_overrides.create! { |override|
              override.set = @course.course_sections.first
              override.due_at = 1.day.ago
              override.due_at_overridden = true
            }
          end

          it "should not overwrite overrides if published twice from the index page" do
            get("/courses/#{@course.id}/assignments", false)
            wait_for_ajaximations

            f("#assignment_#{@assignment.id} .publish-icon").click
            wait_for_ajaximations
            keep_trying_until { @assignment.reload.published? }

            # need to make sure buttons
            keep_trying_until do
              driver.execute_script(
                  "return !$('#assignment_#{@assignment.id} .publish-icon').hasClass('disabled')"
              )
            end

            f("#assignment_#{@assignment.id} .publish-icon").click
            wait_for_ajaximations
            keep_trying_until { !@assignment.reload.published? }

            expect(@assignment.reload.active_assignment_overrides.count).to eq 1
          end

          it "should not overwrite overrides if published twice from the show page" do
            get "/courses/#{@course.id}/assignments/#{@assignment.id}"
            wait_for_ajaximations

            f("#assignment_publish_button").click
            wait_for_ajaximations
            expect(@assignment.reload).to be_published

            f("#assignment_publish_button").click
            wait_for_ajaximations
            expect(@assignment.reload).not_to be_published

            expect(@assignment.reload.active_assignment_overrides.count).to eq 1
          end
        end
      end
    end

    context "menu tools" do
      before do
        course_with_teacher_logged_in(:draft_state => true)
        Account.default.enable_feature!(:lor_for_account)

        @tool = Account.default.context_external_tools.new(:name => "a", :domain => "google.com", :consumer_key => '12345', :shared_secret => 'secret')
        @tool.assignment_menu = {:url => "http://www.example.com", :text => "Export Assignment"}
        @tool.quiz_menu = {:url => "http://www.example.com", :text => "Export Quiz"}
        @tool.discussion_topic_menu = {:url => "http://www.example.com", :text => "Export DiscussionTopic"}
        @tool.save!

        @assignment = @course.assignments.create!(:name => "pls submit", :submission_types => ["online_text_entry"], :points_possible => 20)
      end

      it "should show tool launch links in the gear for items on the index" do
        plain_assignment = @assignment

        quiz_assignment = assignment_model(:submission_types => "online_quiz", :course => @course)
        quiz_assignment.reload
        quiz = quiz_assignment.quiz

        topic_assignment = assignment_model(:course => @course, :submission_types => "discussion_topic", :updating_user => @teacher)
        topic_assignment.reload
        topic = topic_assignment.discussion_topic

        get "/courses/#{@course.id}/assignments"
        wait_for_ajaximations

        gear = f("#assignment_#{plain_assignment.id} .al-trigger")
        gear.click
        link = f("#assignment_#{plain_assignment.id} li a.menu_tool_link")
        expect(link).to be_displayed
        expect(link.text).to match_ignoring_whitespace(@tool.label_for(:assignment_menu))
        expect(link['href']).to eq course_external_tool_url(@course, @tool) + "?launch_type=assignment_menu&assignments[]=#{plain_assignment.id}"

        gear = f("#assignment_#{topic_assignment.id} .al-trigger")
        gear.click
        link = f("#assignment_#{topic_assignment.id} li a.menu_tool_link")
        expect(link).to be_displayed
        expect(link.text).to match_ignoring_whitespace(@tool.label_for(:discussion_topic_menu))
        expect(link['href']).to eq course_external_tool_url(@course, @tool) + "?launch_type=discussion_topic_menu&discussion_topics[]=#{topic.id}"

        gear = f("#assignment_#{quiz_assignment.id} .al-trigger")
        gear.click
        link = f("#assignment_#{quiz_assignment.id} li a.menu_tool_link")
        expect(link).to be_displayed
        expect(link.text).to match_ignoring_whitespace(@tool.label_for(:quiz_menu))
        expect(link['href']).to eq course_external_tool_url(@course, @tool) + "?launch_type=quiz_menu&quizzes[]=#{quiz.id}"
      end

      it "should show tool launch links in the gear for items on the show page" do
        get "/courses/#{@course.id}/assignments/#{@assignment.id}"
        wait_for_ajaximations

        gear = f("#assignment_show .al-trigger")
        gear.click
        link = f("#assignment_show li a.menu_tool_link")
        expect(link).to be_displayed
        expect(link.text).to match_ignoring_whitespace(@tool.label_for(:assignment_menu))
        expect(link['href']).to eq course_external_tool_url(@course, @tool) + "?launch_type=assignment_menu&assignments[]=#{@assignment.id}"
      end
    end
  end
end
