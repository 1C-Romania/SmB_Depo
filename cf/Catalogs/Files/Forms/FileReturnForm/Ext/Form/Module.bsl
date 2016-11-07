
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	File = Parameters.FileRef;
	
	If File.StoreVersions Then
		CreateNewVersion = True;
	Else
		CreateNewVersion = False;
		Items.CreateNewVersion.Enabled = False;
	EndIf;	
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure Save(Command)
	
	ReturnStructure = New Structure("CommentToVersion, CreateNewVersion, ReturnCode",
		CommentToVersion, CreateNewVersion, DialogReturnCode.OK);
	
	Close(ReturnStructure);
	
	Notify("FileOperations_NewFileVersionIsWritten");
	
EndProcedure

&AtClient
Procedure Cancel(Command)
	
	ReturnStructure = New Structure("CommentToVersion, CreateNewVersion, ReturnCode",
		CommentToVersion, CreateNewVersion, DialogReturnCode.Cancel);
	
	Close(ReturnStructure);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure SetUsageParameters(ParametersStructure) Export
	
	Parameters.FileRef = ParametersStructure.FileRef;
	CommentToVersion = ParametersStructure.CommentToVersion;
	File = ParametersStructure.FileRef;
	CreateNewVersion = ParametersStructure.CreateNewVersion;
	Items.CreateNewVersion.Enabled = ParametersStructure.CreateNewVersionEnabled;
	
EndProcedure

#EndRegion



// Rise { Popov N 2016-05-25
&AtClient
Function RiseGetFormInterfaceClient() Export
	Return RiseGetFormInterface();
EndFunction

&AtServer
Function RiseGetFormInterface()
	Return RiseTranslation.GetFormInterface(ThisForm);
EndFunction
// Rise } Popov N 2016-05-25
