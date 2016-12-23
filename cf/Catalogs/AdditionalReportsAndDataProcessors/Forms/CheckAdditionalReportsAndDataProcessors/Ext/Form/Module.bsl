#Region FormCommandsHandlers

&AtClient
Procedure GoToList(Command)
	FilterParameters = New Structure;
	FilterParameters.Insert("CheckAdditionalReportsAndDataProcessors", True);
	
	OpenForm("Catalog.AdditionalReportsAndDataProcessors.Form.ListForm", FilterParameters);
EndProcedure

&AtClient
Procedure CloseForm(Command)
	Close();
EndProcedure

&AtClient
Procedure Checked(Command)
	MarkTaskDone();
	Close();
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure MarkTaskDone()
	
	VersionArray  = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(Metadata.Version, ".");
	CurrentVersion = VersionArray[0] + VersionArray[1] + VersionArray[2];
	CommonSettingsStorage.Save("CurrentWorks", "AdditionalReportsAndDataProcessors", CurrentVersion);
	
EndProcedure

#EndRegion













