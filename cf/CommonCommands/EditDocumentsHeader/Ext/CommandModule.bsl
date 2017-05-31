&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	FormParameters = New Structure;
	FormParameters.Insert("Object", CommandExecuteParameters.Source.Object);
	FormParameters.Insert("ObjectRef", CommandExecuteParameters.Source.Object.Ref);
	FormParameters.Insert("Company", CommandExecuteParameters.Source.Object.Company);
	FormParameters.Insert("Number", CommandExecuteParameters.Source.Object.Number);
	FormParameters.Insert("Date", CommandExecuteParameters.Source.Object.Date);
	
	DocumentNumber = CommandExecuteParameters.Source.Object.Number;
	Notify = New NotifyDescription(
		"ChangeDocumentsHeader",
		CommandExecuteParameters.Source, 
		New Structure("Modified, Company, Number, Date", CommandExecuteParameters.Source.Modified, 
			CommandExecuteParameters.Source.Object.Company,
			DocumentNumber, CommandExecuteParameters.Source.Object.Date));
		
	OpenForm("CommonForm.EditHeader", FormParameters, CommandExecuteParameters.Source,,,,Notify, FormWindowOpeningMode.LockOwnerWindow);
EndProcedure
