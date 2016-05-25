
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
		
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;

	If TypeOf(Object.Owner) = Type("CatalogRef.Files") Then
		Items.FullDescr.ReadOnly = True;
	EndIf;
	
	If Users.InfobaseUserWithFullAccess() Then
		Items.Author.ReadOnly = False;
		Items.CreationDate.ReadOnly = False;
		Items.ParentalVersion.ReadOnly = False;
	Else
		Items.GroupLocation.Visible = False;
	EndIf;
	
	VolumeFullPath = FileFunctionsService.FullPathOfVolume(Object.Volume);
	
	CommonSettings = FileFunctionsServiceClientServer.FileOperationsCommonSettings();
	
	FileExtensionInList = FileFunctionsServiceClientServer.FileExtensionInList(
		CommonSettings.TextFileExtensionsList, Object.Extension);
	
	If FileExtensionInList Then
		If ValueIsFilled(Object.Ref) Then
			
			EncodingValue = FileOperationsServiceServerCall.GetFileVersionEncoding(Object.Ref);
			
			EncodingsList = FileOperationsService.GetEncodingsList();
			ItemOfList = EncodingsList.FindByValue(EncodingValue);
			If ItemOfList = Undefined Then
				Encoding = EncodingValue;
			Else	
				Encoding = ItemOfList.Presentation;
			EndIf;
			
		EndIf;
		
		If Not ValueIsFilled(Encoding) Then
			Encoding = NStr("en='By default'");
		EndIf;
	Else
		Items.Encoding.Visible = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	Notify("Record_File", New Structure("Event", "VersionSaved"), Object.Owner);
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure OpenExecute()
	
	FileData = FileOperationsServiceServerCall.FileDataForOpening(Object.Ref, UUID);
	FileOperationsServiceClient.OpenFileVersion(Undefined, FileData, UUID);
	
EndProcedure

&AtClient
Procedure FullDescrOnChange(Item)
	Object.Description = Object.DescriptionFull;
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure SaveAs(Command)
	
	FileData = FileOperationsServiceServerCall.FileDataForSave(Object.Ref, UUID);
	FileOperationsServiceClient.SaveAs(Undefined, FileData, UUID);
	
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
