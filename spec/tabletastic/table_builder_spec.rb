require 'spec_helper'

describe Tabletastic::TableBuilder do

  before do
    reset_output_buffer!
    mock_everything
    ::Post.stub!(:content_columns).and_return([mock('column', :name => 'title'), mock('column', :name => 'body'), mock('column', :name => 'created_at')])
    @post.stub!(:title).and_return("The title of the post")
    @post.stub!(:body).and_return("Lorem ipsum")
    @post.stub!(:created_at).and_return(Time.now)
    @post.stub!(:id).and_return(2)
    @posts = [@post]
  end

  context "without a block" do
    context "with no other arguments" do
      before do
        concat(table_for(@posts) { |t| t.data })
      end

      subject { output_buffer }

      it { should have_tag("table#posts") }

      it { output_buffer.should have_table_with_tag("thead") } 
      it { output_buffer.should_not have_table_with_tag("tfoot") } 

      it "should have a <th> for each attribute" do
        # title and body
        output_buffer.should have_table_with_tag("th", :count => 2)
      end

      it { output_buffer.should have_table_with_tag("th", "Title") }

      it { output_buffer.should have_table_with_tag("th", "Body") }

      it { output_buffer.should have_table_with_tag("tbody") }

      it "should include a row for each record" do
        output_buffer.should have_table_with_tag("tbody") do |tbody|
          tbody.should have_tag("tr", :count => 1)
        end
      end

      it "should have data for each field" do
        output_buffer.should have_table_with_tag("td", "The title of the post")
        output_buffer.should have_table_with_tag("td", "Lorem ipsum")
      end

      it { output_buffer.should have_table_with_tag("tr#post_#{@post.id}") }

      it "should cycle row classes" do
        reset_output_buffer!
        @posts = [@post, @post]
        concat(
          table_for(@posts) do |t|
            concat(t.data)
          end)
        output_buffer.should have_table_with_tag("tr.odd")
        output_buffer.should have_table_with_tag("tr.even")
      end

      context "mongoid collection" do
        before do
          reset_output_buffer!
          ::Post.stub!(:respond_to?).with(:content_columns).and_return(false)
          ::Post.stub!(:respond_to?).with(:fields).and_return(true)
          ::Post.stub!(:respond_to?).with(:empty?).and_return(false)
          ::Post.stub!(:fields).and_return({'title' => '', 'created_at' => ''})
          concat(table_for(@posts) { |t| t.data })
        end

        it "should detect fields properly" do
          output_buffer.should have_table_with_tag("td", "The title of the post")
          output_buffer.should_not have_table_with_tag("td", "Lorem ipsum")
        end
      end

      context "when collection has associations" do
        it "should handle belongs_to associations" do
          ::Post.stub!(:reflect_on_all_associations).with(:belongs_to).and_return([@mock_reflection_belongs_to_author])
          @posts = [@freds_post]
          concat table_for(@posts) { |t| t.data }
          output_buffer.should have_table_with_tag("th", "Author")
          output_buffer.should have_table_with_tag("td", "Fred Smith")
        end

        it "should handle has_one associations" do
          ::Author.stub!(:reflect_on_all_associations).with(:has_one).and_return([@mock_reflection_has_one_profile])
          concat table_for([@fred]) { |t| t.data }
          output_buffer.should have_table_with_tag("th", "Profile")
        end
      end
    end

    context "with options[:actions]" do
      it "includes path to post for :show" do
        concat(table_for(@posts) do |t|
          t.data(:actions => :show)
        end)
        output_buffer.should have_table_with_tag("a[@href=\"/posts/#{@post.id}\"]")
        output_buffer.should have_table_with_tag("th", "")
      end

      it "should have a cell with default class 'actions' and the action name" do
        concat(table_for(@posts) do |t|
          t.data(:actions => :show)
        end)
        output_buffer.should have_tag("td.actions.show_link") do |td|
          td.should have_tag("a")
        end
      end

      it "includes path to post for :edit" do
        concat(table_for(@posts) do |t|
          t.data(:actions => :edit)
        end)
        output_buffer.should have_tag("a[@href=\"/posts/#{@post.id}/edit\"]", "Edit")
      end

      it "includes path to post for :destroy" do
        concat(table_for(@posts) do |t|
          t.data(:actions => :destroy)
        end)
        output_buffer.should have_table_with_tag("a[@href=\"/posts/#{@post.id}\"]")
        output_buffer.should have_table_with_tag("th", "")
      end

      it "includes path to post for :show and :edit" do
        concat(table_for(@posts) do |t|
          t.data(:actions => [:show, :edit])
        end)
        output_buffer.should have_tag("td:nth-child(3) a[@href=\"/posts/#{@post.id}\"]", "Show")
        output_buffer.should have_tag("td:nth-child(4) a[@href=\"/posts/#{@post.id}/edit\"]", "Edit")
      end

      it "includes path to post for :all" do
        concat(table_for(@posts) do |t|
          t.data(:actions => :all)
        end)
        output_buffer.should have_tag("td:nth-child(3) a[@href=\"/posts/#{@post.id}\"]", "Show")
        output_buffer.should have_tag("td:nth-child(4) a[@href=\"/posts/#{@post.id}/edit\"]", "Edit")
        output_buffer.should have_tag("td:nth-child(5) a[@href=\"/posts/#{@post.id}\"]", "Destroy")
      end

      context "with options[:actions_prefix]" do
        context "with a single symbol as argument" do
          it "includes path to admin post for :show" do
            concat(table_for(@posts) do |t|
              t.data(:actions => :show, :action_prefix => :admin)
            end)
            output_buffer.should have_tag("td:nth-child(3) a[@href=\"/admin/posts/#{@post.id}\"]", "Show")
          end

          it "includes path to admin post for :edit" do
            concat(table_for(@posts) do |t|
              t.data(:actions => :edit, :action_prefix => :admin)
            end)
            output_buffer.should have_tag("td:nth-child(3) a[@href=\"/admin/posts/#{@post.id}/edit\"]", "Edit")
          end

          it "includes path to admin post for :destroy" do
            concat(table_for(@posts) do |t|
              t.data(:actions => :destroy, :action_prefix => :admin)
            end)
            output_buffer.should have_tag("td:nth-child(3) a[@href=\"/admin/posts/#{@post.id}\"]", "Destroy")
          end

          it "includes path to admin for all actions" do
            concat(table_for(@posts) do |t|
              concat(t.data(:actions => :all, :action_prefix => :admin))
            end)
            output_buffer.should have_tag("td:nth-child(3) a[@href=\"/admin/posts/#{@post.id}\"]", "Show")
            output_buffer.should have_tag("td:nth-child(4) a[@href=\"/admin/posts/#{@post.id}/edit\"]", "Edit")
            output_buffer.should have_tag("td:nth-child(5) a[@href=\"/admin/posts/#{@post.id}\"]", "Destroy")
          end
        end

        context "with a resource as an argument" do
          it "nests the link within the resource correctly for :show" do
            concat(table_for(@posts) do |t|
              t.data(:actions => :show, :action_prefix => @fred)
            end)
            output_buffer.should have_tag("td:nth-child(3) a[@href=\"/authors/#{@fred.id}/posts/#{@post.id}\"]", "Show")
          end
        end

        context "with an array as an argument" do
          it "nests correctly for namespace and resource for :show" do
            concat(table_for(@posts) do |t|
              t.data(:actions => :show, :action_prefix => [:admin, @fred])
            end)
            output_buffer.should have_tag(
              "td a[@href=\"/admin/authors/#{@fred.id}/posts/#{@post.id}\"]", "Show")
          end
          it "includes path to admin for all actions" do
            concat(table_for(@posts) do |t|
              concat(t.data(:actions => :all, :action_prefix => [:admin, @fred]))
            end)
            output_buffer.should have_tag(
              "td a[@href=\"/admin/authors/#{@fred.id}/posts/#{@post.id}\"]", "Show")
            output_buffer.should have_tag(
              "td a[@href=\"/admin/authors/#{@fred.id}/posts/#{@post.id}/edit\"]", "Edit")
            output_buffer.should have_tag(
              "td a[@href=\"/admin/authors/#{@fred.id}/posts/#{@post.id}\"]", "Destroy")
          end
        end
      end
    end

    context "with a list of attributes" do
      before do
        concat(table_for(@posts) do |t|
          t.data(:title, :created_at)
        end)
      end
      subject { output_buffer }

      it { should have_table_with_tag("th", "Title") }
      it { should have_table_with_tag("th", "Created at") }
      it { should_not have_table_with_tag("th", "Body") }
      it { should_not have_table_with_tag("tfoot") }
    end

    context "with a list of attributes and options[:actions]" do
      it "includes path to post for :show" do
        concat(table_for(@posts) do |t|
          concat(t.data(:title, :created_at, :actions => :show))
        end)
        output_buffer.should have_tag("th:nth-child(1)", "Title")
        output_buffer.should have_tag("th:nth-child(2)", "Created at")
        output_buffer.should have_tag("th:nth-child(3)", "")
        output_buffer.should_not have_tag("th", "Body")

        output_buffer.should have_tag("td:nth-child(3) a[@href=\"/posts/#{@post.id}\"]")
      end
    end
  end

  context "with a block" do
    context "and normal columns" do
      before do
        concat(table_for(@posts) do |t|
          t.data do
            t.cell(:title)
            t.cell(:body)
          end
        end)
      end

      subject { output_buffer }

      it { should have_table_with_tag("th", "Title") }
      it { should have_tag("td", "The title of the post") }
      it { should have_tag("td", "Lorem ipsum") }
      it { should_not have_table_with_tag("tfoot") }
    end

    context "with custom cell options" do
      before do
        concat(table_for(@posts) do |t|
          t.data do
            t.cell(:title, :heading => "FooBar")
            t.cell(:body, :cell_html => {:class => "batquux"})
          end
        end)
      end

      subject { output_buffer }

      it { should have_table_with_tag("th", "FooBar") }
      it { should have_table_with_tag("th", "Body") }
      it { output_buffer.should_not have_table_with_tag("tfoot") }

      it "should pass :cell_html to the cell" do
        output_buffer.should have_table_with_tag("td.batquux")
      end
    end

    context "with custom heading option" do
      before do
        concat(table_for(@posts) do |t|
          t.data do
            t.cell(:title) {|p| link_to p.title, "/" }
            t.cell(:body, :heading => "Content") {|p| p.body }
          end
        end)
      end

      subject { output_buffer }

      it { should have_table_with_tag("th:nth-child(1)", "Title") }
      it { should have_table_with_tag("th:nth-child(2)", "Content") }
      it { should have_table_with_tag("td:nth-child(2)", "Lorem ipsum") }
      it { should_not have_table_with_tag("tfoot") }

      it "accepts a block as a lazy attribute" do
        output_buffer.should have_table_with_tag("td:nth-child(1)") do |td|
          td.should have_tag("a", "The title of the post")
        end
      end
    end

    context "with a simple footer" do
      before do
        concat(table_for(@posts) do |t|
          t.data do
            t.cell(:title, footer: "My custom footer")
          end
        end)
      end

      subject { output_buffer }

      it { should have_tag("table tfoot tr td", "My custom footer") }
    end

    context "with a counter footer" do
      before do
        concat(table_for(@posts) do |t|
          t.data do
            t.cell(:title, footer: @posts.count)
          end
        end)
      end

      subject { output_buffer }

      it { should have_tag("table tfoot tr td", "1") }
    end

    context "with a summing footer" do
      before do
        concat(table_for(@posts) do |t|
          t.data do
            t.cell(:id, footer: @posts.map(&:id).inject(&:+))
          end
        end)
      end

      subject { output_buffer }

      it { should have_tag("table tfoot tr td", "2") }
    end



    context "with custom heading html option" do
      before do
        concat( table_for(@posts) do |t|
          t.data do
            t.cell(:title, :heading_html => {:class => 'hoja'})
          end
        end)
      end
      subject { output_buffer }
      it { should have_table_with_tag("th.hoja") }
      it { should_not have_table_with_tag("tfoot") }
    end

    context "with options[:actions]" do
      before do
        concat(table_for(@posts) do |t|
          t.data(:actions => :show) do
            t.cell(:title)
            t.cell(:body)
          end
        end)
      end
      subject { output_buffer }
      it { should have_table_with_tag("td:nth-child(3) a[@href=\"/posts/#{@post.id}\"]") }
    end

    context "and normal/association columns" do
      before do
        ::Post.stub!(:reflect_on_all_associations).with(:belongs_to).and_return([@mock_reflection_belongs_to_author])
        @posts = [@freds_post]
        concat(table_for(@posts) do |t|
          t.data do
            t.cell(:title)
            t.cell(:author)
          end
        end)
      end

      it "should include normal columns" do
        output_buffer.should have_table_with_tag("th:nth-child(1)", "Title")
        output_buffer.should have_table_with_tag("td:nth-child(1)", "Fred's Post")
      end

      it "should include belongs_to associations" do
        output_buffer.should have_table_with_tag("th:nth-child(2)", "Author")
        output_buffer.should have_table_with_tag("td:nth-child(2)", "Fred Smith")
      end
    end
  end

  context "using human_attribute_names" do
    before do
      ::Post.stub!(:human_attribute_name).with('body').and_return("Blah blue")

      concat(table_for(@posts) do |t|
        t.data do
          t.cell(:title)
          t.cell(:body)
        end
      end)
    end

    subject { output_buffer }
    it { should have_table_with_tag("th", "Blah blue") }
  end

  context "when table_for is not passed a block" do
    it "the data should use the default option" do
      Tabletastic.default_table_block = lambda {|table| table.data}
      concat( table_for(@posts) )
      output_buffer.should have_table_with_tag("td", "The title of the post")
    end
  end
end
