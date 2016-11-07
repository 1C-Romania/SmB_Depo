
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	// Import passed parameters.
	TransferredFormatsArray = New Array;
	If Parameters.FormatSettings <> Undefined Then
		TransferredFormatsArray = Parameters.FormatSettings.SavingFormats;
		PackIntoArchive = Parameters.FormatSettings.PackIntoArchive;
	EndIf;
	
	// format list filling
	For Each SavingFormat IN PrintManagement.SpreadsheetDocumentSavingFormatsSettings() Do
		Check = False;
		If Parameters.FormatSettings <> Undefined Then 
			TransferredFormat = TransferredFormatsArray.Find(SavingFormat.SpreadsheetDocumentFileType);
			If TransferredFormat <> Undefined Then
				Check = True;
			EndIf;
		EndIf;
		SelectedSavingFormats.Add(SavingFormat.SpreadsheetDocumentFileType, String(SavingFormat.Ref), Check, SavingFormat.Picture);
	EndDo;

EndProcedure

&AtServer
Procedure BeforeImportDataFromSettingsAtServer(Settings)
	If Parameters.FormatSettings <> Undefined AND Parameters.FormatSettings.SavingFormats.Count() > 0 Then
		Settings.Delete("SelectedSavingFormats");
		Settings.Delete("PackIntoArchive");
		Return;
	EndIf;
	
	SavingFromSettingsFormats = Settings["SelectedSavingFormats"];
	If SavingFromSettingsFormats <> Undefined Then
		For Each SelectedFormat IN SelectedSavingFormats Do 
			FormatFromSettings = SavingFromSettingsFormats.FindByValue(SelectedFormat.Value);
			SelectedFormat.Check = FormatFromSettings <> Undefined AND FormatFromSettings.Check;
		EndDo;
		Settings.Delete("SelectedSavingFormats");
	EndIf;
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	SetFormatChoice();
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure Select(Command)
	ChoiceResult = SelectedFormatSettings();
	NotifyChoice(ChoiceResult);
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure SetFormatChoice()
	
	IsSelectedFormat = False;
	For Each SelectedFormat IN SelectedSavingFormats Do
		If SelectedFormat.Check Then
			IsSelectedFormat = True;
		EndIf;
	EndDo;
	
	If Not IsSelectedFormat Then
		SelectedSavingFormats[0].Check = True; // Selection default - first in list.
	EndIf;
	
EndProcedure

&AtClient
Function SelectedFormatSettings()
	
	SavingFormats = New Array;
	
	For Each SelectedFormat IN SelectedSavingFormats Do
		If SelectedFormat.Check Then
			SavingFormats.Add(SelectedFormat.Value);
		EndIf;
	EndDo;	
	
	Result = New Structure;
	Result.Insert("PackIntoArchive", PackIntoArchive);
	Result.Insert("SavingFormats", SavingFormats);
	
	Return Result;
	
EndFunction

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
