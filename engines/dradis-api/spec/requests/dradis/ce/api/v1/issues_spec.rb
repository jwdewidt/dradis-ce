require 'spec_helper'

describe "Issues API" do

  include_context "https"

  context "as unauthenticated user" do
    describe "GET /api/issues" do
      it "throws 401" do
        get "/api/issues", {}, @env
        expect(response.status).to eq(401)
      end
    end
    describe "GET /api/issues/:id" do
      it "throws 401" do
        get "/api/issues/1", {}, @env
        expect(response.status).to eq(401)
      end
    end
    describe "POST /api/issues" do
      it "throws 401" do
        post "/api/issues", {}, @env
        expect(response.status).to eq(401)
      end
    end
    describe "PUT /api/issues/:id" do
      it "throws 401" do
        put "/api/issues/1", {}, @env
        expect(response.status).to eq(401)
      end
    end
    describe "DELETE /api/issues/:id" do
      it "throws 401" do
        delete "/api/issues/1", {}, @env
        expect(response.status).to eq(401)
      end
    end
  end

  context "as authenticated user" do
    include_context "authenticated API user"

    describe "GET /api/issues" do
      before(:each) do
        @issues = create_list(:issue, 10).sort_by(&:title)

        get "/api/issues", {}, @env
        expect(response.status).to eq(200)

        @retrieved_issues = JSON.parse(response.body)
      end

      it "retrieves all the issues" do
        titles = @issues.map(&:title)
        retrieved_titles = @retrieved_issues.map{ |json| json['title'] }

        expect(@retrieved_issues.count).to eq(@issues.count)
        expect(retrieved_titles).to match_array(titles)
      end

      it "includes fields" do
        @retrieved_issues.each do |issue|
          expect(issue).to have_key('id')
          db_issue = Issue.find(issue['id'])

          expect(issue['fields']).not_to be_empty
          expect(issue['fields'].count).to eq(db_issue.fields.count)
          expect(issue['fields'].keys).to eq(db_issue.fields.keys)
        end
      end
    end

    describe "GET /api/issue/:id" do
      before(:each) do
        @issue = create(:issue, text: "#[a]#\nb\n\n#[c]#\nd\n\n#[e]#\nf\n\n")

        get "/api/issues/#{ @issue.id }", {}, @env
        expect(response.status).to eq(200)

        @retrieved_issue = JSON.parse(response.body)
      end

      it "retrieves a specific issue" do
        expect(@retrieved_issue['id']).to eq @issue.id
      end

      it "includes fields" do
        expect(@retrieved_issue['fields']).not_to be_empty
        expect(@retrieved_issue['fields'].keys).to eq @issue.fields.keys
        expect(@retrieved_issue['fields'].count).to eq @issue.fields.count
      end
    end

    describe "POST /api/issues" do
      let(:valid_params) { { issue: { text: "#[Title]#\nRspec issue\n\n#[c]#\nd\n\n#[e]#\nf\n\n" } } }
      let(:valid_post) do
        post "/api/issues", valid_params.to_json, @env.merge("CONTENT_TYPE" => 'application/json')
      end

      it "creates a new issue" do
        expect{valid_post}.to change{Issue.count}.by(1)
        expect(response.status).to eq(201)
        retrieved_issue = JSON.parse(response.body)
        expect(retrieved_issue['text']).to eq params[:issue][:text]
      end

      let(:submit_form) { valid_post }
      include_examples "creates an Activity", :create, Issue

      it "throws 415 unless JSON is sent" do
        params = { issue: { name: "Bad Issue" } }
        post "/api/issues", params, @env
        expect(response.status).to eq(415)
      end

      it "throws 422 if issue is invalid" do
        params = { issue: { text: "A"*(65535+1) } }
        expect {
          post "/api/issues", params.to_json, @env.merge("CONTENT_TYPE" => 'application/json')
        }.not_to change { Issue.count }
        expect(response.status).to eq(422)
      end
    end

    describe "PUT /api/issues/:id" do
      let(:issue) { create(:issue, text: "Existing Issue") }
      let(:valid_params) { { issue: { text: "Updated Issue" } } }
      let(:valid_put) do
        put "/api/issues/#{issue.id}", valid_params.to_json, @env.merge("CONTENT_TYPE" => 'application/json')
      end

      it "updates a issue" do
        valid_put
        expect(response.status).to eq(200)

        expect(Issue.find(issue.id).text).to eq params[:issue][:text]

        retrieved_issue = JSON.parse(response.body)
        expect(retrieved_issue['text']).to eq params[:issue][:text]
      end

      let(:submit_form) { valid_put }
      let(:model) { issue }
      include_examples "creates an Activity", :update

      it "throws 415 unless JSON is sent" do
        params = { issue: { text: "Bad issuet" } }
        put "/api/issues/#{ issue.id }", params, @env
        expect(response.status).to eq(415)
      end

      it "throws 422 if issue is invalid" do
        params = { issue: { text: "B"*(65535+1) } }
        put "/api/issues/#{ issue.id }", params.to_json, @env.merge("CONTENT_TYPE" => 'application/json')
        expect(response.status).to eq(422)
      end
    end

    describe "DELETE /api/issue/:id" do
      let(:issue) { create(:issue) }

      let(:delete_issue) { delete "/api/issues/#{ issue.id }", {}, @env }

      it "deletes a issue" do
        expect(response.status).to eq(200)
        expect { Issue.find(issue.id) }.to raise_error(ActiveRecord::RecordNotFound)
      end

      let(:submit_form) { delete_issue }
      let(:model) { issue }
      include_examples "creates an Activity", :destroy
    end
  end
end