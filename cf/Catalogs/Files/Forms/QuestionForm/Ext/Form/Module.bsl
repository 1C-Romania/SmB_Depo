
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	MessageQuestion = Parameters.MessageQuestion;
	MessageTitle = Parameters.MessageTitle;
	Title = Parameters.Title;
	Files = Parameters.Files;
	
EndProcedure

#EndRegion

#Region FormTableItemEventHandlersFiles

&AtClient
Procedure FilesSelection(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	FileRef = Files[SelectedRow].Value;
	
	PersonalSettings = FileFunctionsServiceClientServer.PersonalFileOperationsSettings();
	HowToOpen = PersonalSettings.DoubleClickAction;
	If HowToOpen = "ToOpenCard" Then
		FormParameters = New Structure;
		FormParameters.Insert("Key", FileRef);
		OpenForm("Catalog.Files.ObjectForm", FormParameters, ThisObject);
		Return;
	EndIf;
	
	FileData = FileOperationsServiceServerCall.FileDataForOpening(FileRef, UUID);
	FileOperationsServiceClient.OpenFileWithAlert(Undefined, FileData);
	
EndProcedure

#EndRegion














