
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	FormFullName = "Catalog.EmailAccounts.ObjectForm";
	
	FormParameters = New Structure("Key", PredefinedValue("Catalog.EmailAccounts.SystemEmailAccount"));
	
	FormOwner = CommandExecuteParameters.Source;
	UniquenessOfForm = CommandExecuteParameters.Uniqueness;
	
	#If WebClient Then
	WindowOfForm = CommandExecuteParameters.Window;
	#Else
	WindowOfForm = CommandExecuteParameters.Source;
	#EndIf
	
	OpenForm(FormFullName, FormParameters, FormOwner, UniquenessOfForm, WindowOfForm);
	
EndProcedure
