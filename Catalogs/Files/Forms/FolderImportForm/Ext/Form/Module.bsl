
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	If Not Parameters.Property("DirectoryOnHardDisk") Then
		CommonUseClientServer.MessageToUser(
			NStr("en = 'This data processor is called from the other configuration procedures.
			           |Prohibited to call it manually.'")); 
		Cancel = True;
		Return;
	EndIf;
	
	If Parameters.DirectoryOnHardDisk <> Undefined Then
		Directory = Parameters.DirectoryOnHardDisk;
	EndIf;
	
	If Parameters.FolderForAdding <> Undefined Then
		FolderForAdding = Parameters.FolderForAdding;
	EndIf;
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	DirectoryChoice = True;
	StoreVersions = True;
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	If Upper(ChoiceSource.FormName) = Upper("Catalog.Files.Form.EncodingChoice") Then
		If TypeOf(ValueSelected) <> Type("Structure") Then
			Return;
		EndIf;
		FileTextEncoding = ValueSelected.Value;
		EncodingPresentation = ValueSelected.Presentation;
		SetEncodingCommandPresentation(EncodingPresentation);
	EndIf;
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure SelectedFolderStartChoice(Item, ChoiceData, StandardProcessing)
	#If Not WebClient Then
		Mode = FileDialogMode.ChooseDirectory;
		
		FileOpeningDialog = New FileDialog(Mode);
		
		FileOpeningDialog.Directory = Directory;
		FileOpeningDialog.FullFileName = "";
		Filter = NStr("en = 'All files(*.*)|*.*'");
		FileOpeningDialog.Filter = Filter;
		FileOpeningDialog.Multiselect = False;
		FileOpeningDialog.Title = NStr("en = 'Select the folder'");
		If FileOpeningDialog.Choose() Then
			
			If DirectoryChoice = True Then 
				
				Directory = FileOpeningDialog.Directory;
				
			EndIf;
			
		EndIf;
			
		StandardProcessing = False;
	#EndIf
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure ImportExecute()
	
	If IsBlankString(Directory) Then
		
		CommonUseClientServer.MessageToUser(
			NStr("en = 'Directory for the import is not selected.'"), , "Directory");
		Return;
		
	EndIf;
	
	If FolderForAdding.IsEmpty() Then
		CommonUseClientServer.MessageToUser(
			NStr("en = 'Specify the folder.'"), , "FolderForAdding");
		Return;
	EndIf;
	
	SelectedFiles = New ValueList;
	SelectedFiles.Add(Directory);
	
	Handler = New NotifyDescription("ImportEnd", ThisObject);
	
	ExecuteParameters = FileOperationsServiceClient.FileImportParameters();
	ExecuteParameters.ResultHandler = Handler;
	ExecuteParameters.Owner = FolderForAdding;
	ExecuteParameters.SelectedFiles = SelectedFiles; 
	ExecuteParameters.Comment = Definition;
	ExecuteParameters.StoreVersions = StoreVersions;
	ExecuteParameters.DeleteFilesAfterAdd = DeleteFilesAfterAdd;
	ExecuteParameters.Recursively = True;
	ExecuteParameters.FormID = UUID;
	ExecuteParameters.Encoding = FileTextEncoding;
	
	FileOperationsServiceClient.ImportFilesExecute(ExecuteParameters);
	
EndProcedure

&AtClient
Procedure ImportEnd(Result, ExecuteParameters) Export
	If Result = Undefined Then
		Return;
	EndIf;
	
	Close();
	Notify("DirectoryImportCompleted", New Structure, Result.FolderForAddCurrent);
EndProcedure

&AtClient
Procedure SelectEncoding(Command)
	FormParameters = New Structure;
	FormParameters.Insert("CurrentEncoding", FileTextEncoding);
	OpenForm("Catalog.Files.Form.EncodingChoice", FormParameters, ThisObject);
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure SetEncodingCommandPresentation(Presentation)
	
	Commands.SelectEncoding.Title = Presentation;
	
EndProcedure

#EndRegion
