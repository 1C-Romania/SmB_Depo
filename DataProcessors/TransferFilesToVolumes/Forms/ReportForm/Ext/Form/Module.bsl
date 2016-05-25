
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	Explanation = Parameters.Explanation;
	
	Spreadsheet = New SpreadsheetDocument;
	TabTemplate = DataProcessors.TransferFilesToVolumes.GetTemplate("ReportTemplate");
	
	HeaderArea = TabTemplate.GetArea("Title");
	HeaderArea.Parameters.Definition = NStr("en = 'Files with errors:'");
	Spreadsheet.Put(HeaderArea);
	
	AreaRow = TabTemplate.GetArea("String");
	
	For Each Selection IN Parameters.FileArrayWithErrors Do
		AreaRow.Parameters.Description = Selection.FileName;
		AreaRow.Parameters.Version = Selection.Version;
		AreaRow.Parameters.Error = Selection.Error;
		Spreadsheet.Put(AreaRow);
	EndDo;
	
	Report.Put(Spreadsheet);
	
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
