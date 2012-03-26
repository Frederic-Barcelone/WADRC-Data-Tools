require 'spec_helper'

# This spec was generated by rspec-rails when you ran the scaffold generator.
# It demonstrates how one might use RSpec to specify the controller code that
# was generated by the Rails when you ran the scaffold generator.

describe LookupRefsController do

  def mock_lookup_ref(stubs={})
    @mock_lookup_ref ||= mock_model(LookupRef, stubs).as_null_object
  end

  describe "GET index" do
    it "assigns all lookup_refs as @lookup_refs" do
      LookupRef.stub(:all) { [mock_lookup_ref] }
      get :index
      assigns(:lookup_refs).should eq([mock_lookup_ref])
    end
  end

  describe "GET show" do
    it "assigns the requested lookup_ref as @lookup_ref" do
      LookupRef.stub(:find).with("37") { mock_lookup_ref }
      get :show, :id => "37"
      assigns(:lookup_ref).should be(mock_lookup_ref)
    end
  end

  describe "GET new" do
    it "assigns a new lookup_ref as @lookup_ref" do
      LookupRef.stub(:new) { mock_lookup_ref }
      get :new
      assigns(:lookup_ref).should be(mock_lookup_ref)
    end
  end

  describe "GET edit" do
    it "assigns the requested lookup_ref as @lookup_ref" do
      LookupRef.stub(:find).with("37") { mock_lookup_ref }
      get :edit, :id => "37"
      assigns(:lookup_ref).should be(mock_lookup_ref)
    end
  end

  describe "POST create" do
    describe "with valid params" do
      it "assigns a newly created lookup_ref as @lookup_ref" do
        LookupRef.stub(:new).with({'these' => 'params'}) { mock_lookup_ref(:save => true) }
        post :create, :lookup_ref => {'these' => 'params'}
        assigns(:lookup_ref).should be(mock_lookup_ref)
      end

      it "redirects to the created lookup_ref" do
        LookupRef.stub(:new) { mock_lookup_ref(:save => true) }
        post :create, :lookup_ref => {}
        response.should redirect_to(lookup_ref_url(mock_lookup_ref))
      end
    end

    describe "with invalid params" do
      it "assigns a newly created but unsaved lookup_ref as @lookup_ref" do
        LookupRef.stub(:new).with({'these' => 'params'}) { mock_lookup_ref(:save => false) }
        post :create, :lookup_ref => {'these' => 'params'}
        assigns(:lookup_ref).should be(mock_lookup_ref)
      end

      it "re-renders the 'new' template" do
        LookupRef.stub(:new) { mock_lookup_ref(:save => false) }
        post :create, :lookup_ref => {}
        response.should render_template("new")
      end
    end
  end

  describe "PUT update" do
    describe "with valid params" do
      it "updates the requested lookup_ref" do
        LookupRef.stub(:find).with("37") { mock_lookup_ref }
        mock_lookup_ref.should_receive(:update_attributes).with({'these' => 'params'})
        put :update, :id => "37", :lookup_ref => {'these' => 'params'}
      end

      it "assigns the requested lookup_ref as @lookup_ref" do
        LookupRef.stub(:find) { mock_lookup_ref(:update_attributes => true) }
        put :update, :id => "1"
        assigns(:lookup_ref).should be(mock_lookup_ref)
      end

      it "redirects to the lookup_ref" do
        LookupRef.stub(:find) { mock_lookup_ref(:update_attributes => true) }
        put :update, :id => "1"
        response.should redirect_to(lookup_ref_url(mock_lookup_ref))
      end
    end

    describe "with invalid params" do
      it "assigns the lookup_ref as @lookup_ref" do
        LookupRef.stub(:find) { mock_lookup_ref(:update_attributes => false) }
        put :update, :id => "1"
        assigns(:lookup_ref).should be(mock_lookup_ref)
      end

      it "re-renders the 'edit' template" do
        LookupRef.stub(:find) { mock_lookup_ref(:update_attributes => false) }
        put :update, :id => "1"
        response.should render_template("edit")
      end
    end
  end

  describe "DELETE destroy" do
    it "destroys the requested lookup_ref" do
      LookupRef.stub(:find).with("37") { mock_lookup_ref }
      mock_lookup_ref.should_receive(:destroy)
      delete :destroy, :id => "37"
    end

    it "redirects to the lookup_refs list" do
      LookupRef.stub(:find) { mock_lookup_ref }
      delete :destroy, :id => "1"
      response.should redirect_to(lookup_refs_url)
    end
  end

end