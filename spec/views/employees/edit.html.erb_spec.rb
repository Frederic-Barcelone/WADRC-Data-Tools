require 'spec_helper'

describe "employees/edit.html.erb" do
  before(:each) do
    @employee = assign(:employee, stub_model(Employee,
      :first_name => "MyString",
      :mi => "MyString",
      :last_name => "MyString",
      :status => "MyString",
      :initials => "MyString",
      :lookup_status_id => 1,
      :user_id => 1
    ))
  end

  it "renders the edit employee form" do
    render

    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "form", :action => employee_path(@employee), :method => "post" do
      assert_select "input#employee_first_name", :name => "employee[first_name]"
      assert_select "input#employee_mi", :name => "employee[mi]"
      assert_select "input#employee_last_name", :name => "employee[last_name]"
      assert_select "input#employee_status", :name => "employee[status]"
      assert_select "input#employee_initials", :name => "employee[initials]"
      assert_select "input#employee_lookup_status_id", :name => "employee[lookup_status_id]"
      assert_select "input#employee_user_id", :name => "employee[user_id]"
    end
  end
end
