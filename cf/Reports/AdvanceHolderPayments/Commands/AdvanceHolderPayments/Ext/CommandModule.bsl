&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	Filter = New Structure;
	Filter.Insert("Employee", GetEmployeeArray(CommandParameter));
	
	OpenForm("Report.AdvanceHolderPayments.Form",
		New Structure("UsePurposeKey, Filter, GenerateOnOpen", CommandParameter, Filter, True),
		,
		"Employee=" + CommandParameter,
		CommandExecuteParameters.Window
	);
	
EndProcedure // CommandProcessing()

&AtServer
Function GetEmployeeArray(CommandParameter)

	EmployeeArray = New Array;
	
	If TypeOf(CommandParameter) = Type("Array") Then
		For Each Document IN CommandParameter Do
			If TypeOf(Document) = Type("DocumentRef.ExpenseReport") Then
				Employee = CommonUse.ObjectAttributeValue(Document, "Employee");
				EmployeeArray.Add(Employee);
			Else
				Employee = CommonUse.ObjectAttributeValue(Document, "AdvanceHolder");
				EmployeeArray.Add(Employee);
			EndIf;
		EndDo;
	EndIf;
	
	Return EmployeeArray;

EndFunction // GetOrderArray()
