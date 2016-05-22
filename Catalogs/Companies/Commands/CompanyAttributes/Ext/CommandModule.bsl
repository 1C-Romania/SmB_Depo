
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	OpenForm("Catalog.Companies.ObjectForm", GetFormsOpeningParameters());
	
EndProcedure

&AtServer
Function GetFormsOpeningParameters()
	
	Return New Structure("Key", Catalogs.Companies.CompanyByDefault());
	
EndFunction
