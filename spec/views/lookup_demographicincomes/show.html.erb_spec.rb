require 'spec_helper'

describe "lookup_demographicincomes/show.html.erb" do
  before(:each) do
    @lookup_demographicincome = assign(:lookup_demographicincome, stub_model(LookupDemographicincome,
      :description => "Description"
    ))
  end

  it "renders attributes in <p>" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    rendered.should match(/Description/)
  end
end
