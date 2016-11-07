
&AtServer
Function GetCurrentUserEmployees()

	Query = New Query;
	
	Query.SetParameter("User",Users.CurrentUser());
	Query.Text = "SELECT
	               |	UserEmployees.Employee
	               |FROM
	               |	InformationRegister.UserEmployees AS UserEmployees
	               |WHERE
	               |	UserEmployees.User = &User";
				   
	EmployeeArray = Query.Execute().Unload().UnloadColumn("Employee");
	
	Return EmployeeArray;	   

EndFunction


&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	
	Employees = GetCurrentUserEmployees();
	
	OpenForm("Report.WorkOrders.Form",
		New Structure("GenerateOnOpen,Filter", True, New Structure("Employee", Employees)));

EndProcedure
