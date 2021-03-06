require 'spec_helper'

# This spec was generated by rspec-rails when you ran the scaffold generator.
# It demonstrates how one might use RSpec to specify the controller code that
# was generated by the Rails when you ran the scaffold generator.

describe LookupTruthtablesController do

  def mock_lookup_truthtable(stubs={})
    @mock_lookup_truthtable ||= mock_model(LookupTruthtable, stubs).as_null_object
  end

  describe "GET index" do
    it "assigns all lookup_truthtables as @lookup_truthtables" do
      LookupTruthtable.stub(:all) { [mock_lookup_truthtable] }
      get :index
      assigns(:lookup_truthtables).should eq([mock_lookup_truthtable])
    end
  end

  describe "GET show" do
    it "assigns the requested lookup_truthtable as @lookup_truthtable" do
      LookupTruthtable.stub(:find).with("37") { mock_lookup_truthtable }
      get :show, :id => "37"
      assigns(:lookup_truthtable).should be(mock_lookup_truthtable)
    end
  end

  describe "GET new" do
    it "assigns a new lookup_truthtable as @lookup_truthtable" do
      LookupTruthtable.stub(:new) { mock_lookup_truthtable }
      get :new
      assigns(:lookup_truthtable).should be(mock_lookup_truthtable)
    end
  end

  describe "GET edit" do
    it "assigns the requested lookup_truthtable as @lookup_truthtable" do
      LookupTruthtable.stub(:find).with("37") { mock_lookup_truthtable }
      get :edit, :id => "37"
      assigns(:lookup_truthtable).should be(mock_lookup_truthtable)
    end
  end

  describe "POST create" do
    describe "with valid params" do
      it "assigns a newly created lookup_truthtable as @lookup_truthtable" do
        LookupTruthtable.stub(:new).with({'these' => 'params'}) { mock_lookup_truthtable(:save => true) }
        post :create, :lookup_truthtable => {'these' => 'params'}
        assigns(:lookup_truthtable).should be(mock_lookup_truthtable)
      end

      it "redirects to the created lookup_truthtable" do
        LookupTruthtable.stub(:new) { mock_lookup_truthtable(:save => true) }
        post :create, :lookup_truthtable => {}
        response.should redirect_to(lookup_truthtable_url(mock_lookup_truthtable))
      end
    end

    describe "with invalid params" do
      it "assigns a newly created but unsaved lookup_truthtable as @lookup_truthtable" do
        LookupTruthtable.stub(:new).with({'these' => 'params'}) { mock_lookup_truthtable(:save => false) }
        post :create, :lookup_truthtable => {'these' => 'params'}
        assigns(:lookup_truthtable).should be(mock_lookup_truthtable)
      end

      it "re-renders the 'new' template" do
        LookupTruthtable.stub(:new) { mock_lookup_truthtable(:save => false) }
        post :create, :lookup_truthtable => {}
        response.should render_template("new")
      end
    end
  end

  describe "PUT update" do
    describe "with valid params" do
      it "updates the requested lookup_truthtable" do
        LookupTruthtable.stub(:find).with("37") { mock_lookup_truthtable }
        mock_lookup_truthtable.should_receive(:update_attributes).with({'these' => 'params'})
        put :update, :id => "37", :lookup_truthtable => {'these' => 'params'}
      end

      it "assigns the requested lookup_truthtable as @lookup_truthtable" do
        LookupTruthtable.stub(:find) { mock_lookup_truthtable(:update_attributes => true) }
        put :update, :id => "1"
        assigns(:lookup_truthtable).should be(mock_lookup_truthtable)
      end

      it "redirects to the lookup_truthtable" do
        LookupTruthtable.stub(:find) { mock_lookup_truthtable(:update_attributes => true) }
        put :update, :id => "1"
        response.should redirect_to(lookup_truthtable_url(mock_lookup_truthtable))
      end
    end

    describe "with invalid params" do
      it "assigns the lookup_truthtable as @lookup_truthtable" do
        LookupTruthtable.stub(:find) { mock_lookup_truthtable(:update_attributes => false) }
        put :update, :id => "1"
        assigns(:lookup_truthtable).should be(mock_lookup_truthtable)
      end

      it "re-renders the 'edit' template" do
        LookupTruthtable.stub(:find) { mock_lookup_truthtable(:update_attributes => false) }
        put :update, :id => "1"
        response.should render_template("edit")
      end
    end
  end

  describe "DELETE destroy" do
    it "destroys the requested lookup_truthtable" do
      LookupTruthtable.stub(:find).with("37") { mock_lookup_truthtable }
      mock_lookup_truthtable.should_receive(:destroy)
      delete :destroy, :id => "37"
    end

    it "redirects to the lookup_truthtables list" do
      LookupTruthtable.stub(:find) { mock_lookup_truthtable }
      delete :destroy, :id => "1"
      response.should redirect_to(lookup_truthtables_url)
    end
  end

end
