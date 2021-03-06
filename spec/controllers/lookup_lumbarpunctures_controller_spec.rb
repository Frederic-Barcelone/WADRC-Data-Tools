require 'spec_helper'

# This spec was generated by rspec-rails when you ran the scaffold generator.
# It demonstrates how one might use RSpec to specify the controller code that
# was generated by the Rails when you ran the scaffold generator.

describe LookupLumbarpuncturesController do

  def mock_lookup_lumbarpuncture(stubs={})
    @mock_lookup_lumbarpuncture ||= mock_model(LookupLumbarpuncture, stubs).as_null_object
  end

  describe "GET index" do
    it "assigns all lookup_lumbarpunctures as @lookup_lumbarpunctures" do
      LookupLumbarpuncture.stub(:all) { [mock_lookup_lumbarpuncture] }
      get :index
      assigns(:lookup_lumbarpunctures).should eq([mock_lookup_lumbarpuncture])
    end
  end

  describe "GET show" do
    it "assigns the requested lookup_lumbarpuncture as @lookup_lumbarpuncture" do
      LookupLumbarpuncture.stub(:find).with("37") { mock_lookup_lumbarpuncture }
      get :show, :id => "37"
      assigns(:lookup_lumbarpuncture).should be(mock_lookup_lumbarpuncture)
    end
  end

  describe "GET new" do
    it "assigns a new lookup_lumbarpuncture as @lookup_lumbarpuncture" do
      LookupLumbarpuncture.stub(:new) { mock_lookup_lumbarpuncture }
      get :new
      assigns(:lookup_lumbarpuncture).should be(mock_lookup_lumbarpuncture)
    end
  end

  describe "GET edit" do
    it "assigns the requested lookup_lumbarpuncture as @lookup_lumbarpuncture" do
      LookupLumbarpuncture.stub(:find).with("37") { mock_lookup_lumbarpuncture }
      get :edit, :id => "37"
      assigns(:lookup_lumbarpuncture).should be(mock_lookup_lumbarpuncture)
    end
  end

  describe "POST create" do
    describe "with valid params" do
      it "assigns a newly created lookup_lumbarpuncture as @lookup_lumbarpuncture" do
        LookupLumbarpuncture.stub(:new).with({'these' => 'params'}) { mock_lookup_lumbarpuncture(:save => true) }
        post :create, :lookup_lumbarpuncture => {'these' => 'params'}
        assigns(:lookup_lumbarpuncture).should be(mock_lookup_lumbarpuncture)
      end

      it "redirects to the created lookup_lumbarpuncture" do
        LookupLumbarpuncture.stub(:new) { mock_lookup_lumbarpuncture(:save => true) }
        post :create, :lookup_lumbarpuncture => {}
        response.should redirect_to(lookup_lumbarpuncture_url(mock_lookup_lumbarpuncture))
      end
    end

    describe "with invalid params" do
      it "assigns a newly created but unsaved lookup_lumbarpuncture as @lookup_lumbarpuncture" do
        LookupLumbarpuncture.stub(:new).with({'these' => 'params'}) { mock_lookup_lumbarpuncture(:save => false) }
        post :create, :lookup_lumbarpuncture => {'these' => 'params'}
        assigns(:lookup_lumbarpuncture).should be(mock_lookup_lumbarpuncture)
      end

      it "re-renders the 'new' template" do
        LookupLumbarpuncture.stub(:new) { mock_lookup_lumbarpuncture(:save => false) }
        post :create, :lookup_lumbarpuncture => {}
        response.should render_template("new")
      end
    end
  end

  describe "PUT update" do
    describe "with valid params" do
      it "updates the requested lookup_lumbarpuncture" do
        LookupLumbarpuncture.stub(:find).with("37") { mock_lookup_lumbarpuncture }
        mock_lookup_lumbarpuncture.should_receive(:update_attributes).with({'these' => 'params'})
        put :update, :id => "37", :lookup_lumbarpuncture => {'these' => 'params'}
      end

      it "assigns the requested lookup_lumbarpuncture as @lookup_lumbarpuncture" do
        LookupLumbarpuncture.stub(:find) { mock_lookup_lumbarpuncture(:update_attributes => true) }
        put :update, :id => "1"
        assigns(:lookup_lumbarpuncture).should be(mock_lookup_lumbarpuncture)
      end

      it "redirects to the lookup_lumbarpuncture" do
        LookupLumbarpuncture.stub(:find) { mock_lookup_lumbarpuncture(:update_attributes => true) }
        put :update, :id => "1"
        response.should redirect_to(lookup_lumbarpuncture_url(mock_lookup_lumbarpuncture))
      end
    end

    describe "with invalid params" do
      it "assigns the lookup_lumbarpuncture as @lookup_lumbarpuncture" do
        LookupLumbarpuncture.stub(:find) { mock_lookup_lumbarpuncture(:update_attributes => false) }
        put :update, :id => "1"
        assigns(:lookup_lumbarpuncture).should be(mock_lookup_lumbarpuncture)
      end

      it "re-renders the 'edit' template" do
        LookupLumbarpuncture.stub(:find) { mock_lookup_lumbarpuncture(:update_attributes => false) }
        put :update, :id => "1"
        response.should render_template("edit")
      end
    end
  end

  describe "DELETE destroy" do
    it "destroys the requested lookup_lumbarpuncture" do
      LookupLumbarpuncture.stub(:find).with("37") { mock_lookup_lumbarpuncture }
      mock_lookup_lumbarpuncture.should_receive(:destroy)
      delete :destroy, :id => "37"
    end

    it "redirects to the lookup_lumbarpunctures list" do
      LookupLumbarpuncture.stub(:find) { mock_lookup_lumbarpuncture }
      delete :destroy, :id => "1"
      response.should redirect_to(lookup_lumbarpunctures_url)
    end
  end

end
