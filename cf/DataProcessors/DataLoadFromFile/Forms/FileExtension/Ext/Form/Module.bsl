#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure Select(Command)
	If SavedFileType = 0 Then 
		Result = "xlsx";
	ElsIf SavedFileType = 1 Then 
		Result = "csv";
	Else
		Result = "mxl";
	EndIf;
	Close(Result);
EndProcedure

&AtClient
Procedure InstallAddOnToFacilitateFileOperations(Command)
	BeginInstallFileSystemExtension(Undefined);
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
