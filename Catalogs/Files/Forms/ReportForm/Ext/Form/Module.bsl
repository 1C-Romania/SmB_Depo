
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	Report = FileOperationsServiceServerCall.FilesImportGenerateReport(
		Parameters.FilenamesWithErrorsArray);
	
	If Parameters.Property("Title") Then
		Title = Parameters.Title;
	EndIf;
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure ReportSelection(Item, Area, StandardProcessing)
	
#If Not WebClient Then
	// Path to file.
	If Find(Area.Text, ":\") > 0 OR Find(Area.Text, ":/") > 0 Then
		FileFunctionsServiceClient.OpenExplorerWithFile(Area.Text);
	EndIf;
#EndIf
	
EndProcedure

#EndRegion
