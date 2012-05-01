require 'spec_helper'

# This spec was generated by rspec-rails when you ran the scaffold generator.
# It demonstrates how one might use RSpec to specify the controller code that
# was generated by the Rails when you ran the scaffold generator.

describe LumbarpunctureResultsController do

  def mock_lumbarpuncture_result(stubs={})
    @mock_lumbarpuncture_result ||= mock_model(LumbarpunctureResult, stubs).as_null_object
  end

  describe "GET index" do
    it "assigns all lumbarpuncture_results as @lumbarpuncture_results" do
      LumbarpunctureResult.stub(:all) { [mock_lumbarpuncture_result] }
      get :index
      assigns(:lumbarpuncture_results).should eq([mock_lumbarpuncture_result])
    end
  end

  describe "GET show" do
    it "assigns the requested lumbarpuncture_result as @lumbarpuncture_result" do
      LumbarpunctureResult.stub(:find).with("37") { mock_lumbarpuncture_result }
      get :show, :id => "37"
      assigns(:lumbarpuncture_result).should be(mock_lumbarpuncture_result)
    end
  end

  describe "GET new" do
    it "assigns a new lumbarpuncture_result as @lumbarpuncture_result" do
      LumbarpunctureResult.stub(:new) { mock_lumbarpuncture_result }
      get :new
      assigns(:lumbarpuncture_result).should be(mock_lumbarpuncture_result)
    end
  end

  describe "GET edit" do
    it "assigns the requested lumbarpuncture_result as @lumbarpuncture_result" do
      LumbarpunctureResult.stub(:find).with("37") { mock_lumbarpuncture_result }
      get :edit, :id => "37"
      assigns(:lumbarpuncture_result).should be(mock_lumbarpuncture_result)
    end
  end

  describe "POST create" do
    describe "with valid params" do
      it "assigns a newly created lumbarpuncture_result as @lumbarpuncture_result" do
        LumbarpunctureResult.stub(:new).with({'these' => 'params'}) { mock_lumbarpuncture_result(:save => true) }
        post :create, :lumbarpuncture_result => {'these' => 'params'}
        assigns(:lumbarpuncture_result).should be(mock_lumbarpuncture_result)
      end

      it "redirects to the created lumbarpuncture_result" do
        LumbarpunctureResult.stub(:new) { mock_lumbarpuncture_result(:save => true) }
        post :create, :lumbarpuncture_result => {}
        response.should redirect_to(lumbarpuncture_result_url(mock_lumbarpuncture_result))
      end
    end

    describe "with invalid params" do
      it "assigns a newly created but unsaved lumbarpuncture_result as @lumbarpuncture_result" do
        LumbarpunctureResult.stub(:new).with({'these' => 'params'}) { mock_lumbarpuncture_result(:save => false) }
        post :create, :lumbarpuncture_result => {'these' => 'params'}
        assigns(:lumbarpuncture_result).should be(mock_lumbarpuncture_result)
      end

      it "re-renders the 'new' template" do
        LumbarpunctureResult.stub(:new) { mock_lumbarpuncture_result(:save => false) }
        post :create, :lumbarpuncture_result => {}
        response.should render_template("new")
      end
    end
  end

  describe "PUT update" do
    describe "with valid params" do
      it "updates the requested lumbarpuncture_result" do
        LumbarpunctureResult.stub(:find).with("37") { mock_lumbarpuncture_result }
        mock_lumbarpuncture_result.should_receive(:update_attributes).with({'these' => 'params'})
        put :update, :id => "37", :lumbarpuncture_result => {'these' => 'params'}
      end

      it "assigns the requested lumbarpuncture_result as @lumbarpuncture_result" do
        LumbarpunctureResult.stub(:find) { mock_lumbarpuncture_result(:update_attributes => true) }
        put :update, :id => "1"
        assigns(:lumbarpuncture_result).should be(mock_lumbarpuncture_result)
      end

      it "redirects to the lumbarpuncture_result" do
        LumbarpunctureResult.stub(:find) { mock_lumbarpuncture_result(:update_attributes => true) }
        put :update, :id => "1"
        response.should redirect_to(lumbarpuncture_result_url(mock_lumbarpuncture_result))
      end
    end

    describe "with invalid params" do
      it "assigns the lumbarpuncture_result as @lumbarpuncture_result" do
        LumbarpunctureResult.stub(:find) { mock_lumbarpuncture_result(:update_attributes => false) }
        put :update, :id => "1"
        assigns(:lumbarpuncture_result).should be(mock_lumbarpuncture_result)
      end

      it "re-renders the 'edit' template" do
        LumbarpunctureResult.stub(:find) { mock_lumbarpuncture_result(:update_attributes => false) }
        put :update, :id => "1"
        response.should render_template("edit")
      end
    end
  end

  describe "DELETE destroy" do
    it "destroys the requested lumbarpuncture_result" do
      LumbarpunctureResult.stub(:find).with("37") { mock_lumbarpuncture_result }
      mock_lumbarpuncture_result.should_receive(:destroy)
      delete :destroy, :id => "37"
    end

    it "redirects to the lumbarpuncture_results list" do
      LumbarpunctureResult.stub(:find) { mock_lumbarpuncture_result }
      delete :destroy, :id => "1"
      response.should redirect_to(lumbarpuncture_results_url)
    end
  end

end