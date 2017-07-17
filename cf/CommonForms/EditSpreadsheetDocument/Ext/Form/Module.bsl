
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;

	If Parameters.WindowOpeningMode <> Undefined Then
		WindowOpeningMode = Parameters.WindowOpeningMode;
	EndIf;
	
	If Parameters.SpreadsheetDocument = Undefined Then
		If Not IsBlankString(Parameters.MetadataObjectTemplateName) Then
			ImportSpreadsheetDocumentFormMetadata();
		EndIf;
		
	ElsIf TypeOf(Parameters.SpreadsheetDocument) = Type("SpreadsheetDocument") Then
		SpreadsheetDocument = Parameters.SpreadsheetDocument;
	Else
		BinaryData = GetFromTempStorage(Parameters.SpreadsheetDocument);
		TempFileName = GetTempFileName("mxl");
		BinaryData.Write(TempFileName);
		SpreadsheetDocument.Read(TempFileName);
		DeleteFiles(TempFileName);
	EndIf;
	
	Items.SpreadsheetDocument.Edit = Parameters.Edit;
	Items.SpreadsheetDocument.ShowGroups = True;
	
	IsTemplate = Not IsBlankString(Parameters.MetadataObjectTemplateName);
	Items.Warning.Visible = IsTemplate AND Parameters.Edit;
	
	Items.EditInExternalApplication.Visible = CommonUseClientServer.ThisIsWebClient() 
		AND Not IsBlankString(Parameters.MetadataObjectTemplateName) AND CommonUse.SubsystemExists("StandardSubsystems.Print");
	
	If Not IsBlankString(Parameters.DocumentName) Then
		DocumentName = Parameters.DocumentName;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If Not IsBlankString(Parameters.PathToFile) Then
		NotifyDescription = New NotifyDescription("WhenInitializationFileIsComplete", ThisObject);
		File = New File();
		File.BeginInitialization(NOTifyDescription, Parameters.PathToFile);
		Return;
	EndIf;
	
	SetInitialFormSettings();
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	QuestionText = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Save changes in %1?';ru='Сохранить изменения в %1?'"), DocumentName);
	NotifyDescription = New NotifyDescription("ConfirmAndClose", ThisObject);
	CommonUseClient.ShowFormClosingConfirmation(NOTifyDescription, Cancel, QuestionText);
	
	If Not Modified Then
		NotificationParameters = New Structure;
		NotificationParameters.Insert("PathToFile", Parameters.PathToFile);
		NotificationParameters.Insert("MetadataObjectTemplateName", Parameters.MetadataObjectTemplateName);
		If Recorded Then
			EventName = "Write_SpreadsheetDocument";
			NotificationParameters.Insert("SpreadsheetDocument", SpreadsheetDocument);
		Else
			EventName = "CancelEditSpreadsheetDocument";
		EndIf;
		Notify(EventName, NotificationParameters, ThisObject);
	EndIf;
	
EndProcedure

&AtClient
Procedure ConfirmAndClose(Result = Undefined, AdditionalParameters = Undefined) Export
	NotifyDescription = New NotifyDescription("CloseFormAfterWriteSpreadsheetDocument", ThisObject);
	WriteSpreadsheetDocument(NOTifyDescription);
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	If EventName = "QueryOfEditingSpreadsheetDocumentsNames" AND Source <> ThisObject Then
		Parameter.Add(DocumentName);
	ElsIf EventName = "ClosingOfOwnersForm" AND Source = FormOwner Then
		Close();
		If IsOpen() Then
			Parameter.Cancel = True;
		EndIf;
	EndIf;
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure SpreadsheetDocumentOnActivateArea(Item)
	RefreshMarksOfCommandBarButtons();
EndProcedure

#EndRegion

#Region FormCommandsHandlers

// Operations with document

&AtClient
Procedure WriteAndClose(Command)
	NotifyDescription = New NotifyDescription("CloseFormAfterWriteSpreadsheetDocument", ThisObject);
	WriteSpreadsheetDocument(NOTifyDescription);
EndProcedure

&AtClient
Procedure Write(Command)
	WriteSpreadsheetDocument();
EndProcedure

&AtClient
Procedure Edit(Command)
	Items.SpreadsheetDocument.Edit = Not Items.SpreadsheetDocument.Edit;
	CustomizeCommandsPresentation();
	CustomizeTableDocumentRepresentation();
EndProcedure

&AtClient
Procedure EditInExternalApplication(Command)
	If CommonUseClient.SubsystemExists("StandardSubsystems.Print") Then
		OpenParameters = New Structure;
		OpenParameters.Insert("SpreadsheetDocument", SpreadsheetDocument);
		OpenParameters.Insert("MetadataObjectTemplateName", Parameters.MetadataObjectTemplateName);
		OpenParameters.Insert("TemplateType", "MXL");
		NotifyDescription = New NotifyDescription("EditInExternalApplicationEnd", ThisObject);
		PrintManagementModuleClient = CommonUseClient.CommonModule("PrintManagementClient");
		PrintManagementModuleClient.EditTemplateInExternalApplication(NOTifyDescription, OpenParameters, ThisObject);
	EndIf;
EndProcedure

// Formatting

&AtClient
Procedure IncreaseFontSize(Command)
	
	For Each Area IN ListOfAreasForFontChanges() Do
		Size = Area.Font.Size;
		Size = Size + StepChangesFontSizeIncreasing(Size);
		Area.Font = New Font(Area.Font,,Size);
	EndDo;
	
EndProcedure

&AtClient
Procedure DecreaseFontSize(Command)
	
	For Each Area IN ListOfAreasForFontChanges() Do
		Size = Area.Font.Size;
		Size = Size - StepChangesFontSizeReduction(Size);
		If Size < 1 Then
			Size = 1;
		EndIf;
		Area.Font = New Font(Area.Font,,Size);
	EndDo;
	
EndProcedure

&AtClient
Procedure Strikeout(Command)
	
	SettingValue = Undefined;
	For Each Area IN ListOfAreasForFontChanges() Do
		If SettingValue = Undefined Then
			SettingValue = Not Area.Font.Strikeout = True;
		EndIf;
		Area.Font = New Font(Area.Font,,,,,,SettingValue);
	EndDo;
	
	RefreshMarksOfCommandBarButtons();
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure ImportSpreadsheetDocumentFormMetadata()
	If CommonUse.SubsystemExists("StandardSubsystems.Print") Then
		PrintManagementModule = CommonUse.CommonModule("PrintManagement");
		SpreadsheetDocument = PrintManagementModule.PrintedFormsTemplate(Parameters.MetadataObjectTemplateName);
	EndIf;
EndProcedure

&AtClient
Procedure CustomizeTableDocumentRepresentation()
	Items.SpreadsheetDocument.ShowHeaders = Items.SpreadsheetDocument.Edit;
	Items.SpreadsheetDocument.ShowGrid = Items.SpreadsheetDocument.Edit;
EndProcedure

&AtClient
Procedure RefreshMarksOfCommandBarButtons();
	
	#If Not WebClient Then
	Area = Items.SpreadsheetDocument.CurrentArea;
	If TypeOf(Area) <> Type("SpreadsheetDocumentRange") Then
		Return;
	EndIf;
	
	// Font
	Font = Area.Font;
	Items.SpreadsheetDocumentBold.Check = Font <> Undefined AND Font.Bold = True;
	Items.SpreadsheetDocumentItalic.Check = Font <> Undefined AND Font.Italic = True;
	Items.SpreadsheetDocumentUnderline.Check = Font <> Undefined AND Font.Underline = True;
	Items.Strikeout.Check = Font <> Undefined AND Font.Strikeout = True;
	
	// Horizontal position
	Items.SpreadsheetDocumentAlignLeft.Check = Area.HorizontalAlign = HorizontalAlign.Left;
	Items.SpreadsheetDocumentAlignCenter.Check = Area.HorizontalAlign = HorizontalAlign.Center;
	Items.SpreadsheetDocumentAlignRight.Check = Area.HorizontalAlign = HorizontalAlign.Right;
	Items.SpreadsheetDocumentJustify.Check = Area.HorizontalAlign = HorizontalAlign.Justify;
	
#EndIf
	
EndProcedure

&AtClient
Function StepChangesFontSizeIncreasing(Size)
	If Size = -1 Then
		Return 10;
	EndIf;
	
	If Size < 10 Then
		Return 1;
	ElsIf 10 <= Size AND  Size < 20 Then
		Return 2;
	ElsIf 20 <= Size AND  Size < 48 Then
		Return 4;
	ElsIf 48 <= Size AND  Size < 72 Then
		Return 6;
	ElsIf 72 <= Size AND  Size < 96 Then
		Return 8;
	Else
		Return Round(Size / 10);
	EndIf;
EndFunction

&AtClient
Function StepChangesFontSizeReduction(Size)
	If Size = -1 Then
		Return -8;
	EndIf;
	
	If Size <= 11 Then
		Return 1;
	ElsIf 11 < Size AND Size <= 23 Then
		Return 2;
	ElsIf 23 < Size AND Size <= 53 Then
		Return 4;
	ElsIf 53 < Size AND Size <= 79 Then
		Return 6;
	ElsIf 79 < Size AND Size <= 105 Then
		Return 8;
	Else
		Return Round(Size / 11);
	EndIf;
EndFunction

&AtClient
Function ListOfAreasForFontChanges()
	
	Result = New Array;
	
	For Each ProcessingArea IN Items.SpreadsheetDocument.GetSelectedAreas() Do
		If ProcessingArea.Font <> Undefined Then
			Result.Add(ProcessingArea);
			Continue;
		EndIf;
		
		ProcessingAreaTop = ProcessingArea.Top;
		ProcessingAreaBottom = ProcessingArea.Bottom;
		ProcessingAreaLeft = ProcessingArea.Left;
		ProcessingAreaRight = ProcessingArea.Right;
		
		If ProcessingAreaTop = 0 Then
			ProcessingAreaTop = 1;
		EndIf;
		
		If ProcessingAreaBottom = 0 Then
			ProcessingAreaBottom = SpreadsheetDocument.TableHeight;
		EndIf;
		
		If ProcessingAreaLeft = 0 Then
			ProcessingAreaLeft = 1;
		EndIf;
		
		If ProcessingAreaRight = 0 Then
			ProcessingAreaRight = SpreadsheetDocument.TableWidth;
		EndIf;
		
		If ProcessingArea.AreaType = SpreadsheetDocumentCellAreaType.Columns Then
			ProcessingAreaTop = ProcessingArea.Bottom;
			ProcessingAreaBottom = SpreadsheetDocument.TableHeight;
		EndIf;
			
		For ColumnNumber = ProcessingAreaLeft To ProcessingAreaRight Do
			ColumnWidth = Undefined;
			For LineNumber = ProcessingAreaTop To ProcessingAreaBottom Do
				Cell = SpreadsheetDocument.Area(LineNumber, ColumnNumber, LineNumber, ColumnNumber);
				If ProcessingArea.AreaType = SpreadsheetDocumentCellAreaType.Columns Then
					If ColumnWidth = Undefined Then
						ColumnWidth = Cell.ColumnWidth;
					EndIf;
					If Cell.ColumnWidth <> ColumnWidth Then
						Continue;
					EndIf;
				EndIf;
				If Cell.Font <> Undefined Then
					Result.Add(Cell);
				EndIf;
			EndDo;
		EndDo;
	EndDo;
	
	Return Result;
	
EndFunction

&AtClient
Procedure CloseFormAfterWriteSpreadsheetDocument(Close, AdditionalParameters) Export
	If Close Then
		Close();
	EndIf;
EndProcedure

&AtClient
Procedure WriteSpreadsheetDocument(EndProcessor = Undefined)
	
	If IsNew() Or EditProhibited Then
		StartSaveFileDialog(EndProcessor);
		Return;
	EndIf;
		
	WriteSpreadsheetDocumentFileNameSelected(EndProcessor);
	
EndProcedure

&AtClient
Procedure WriteSpreadsheetDocumentFileNameSelected(Val EndProcessor)
	
	If Not IsBlankString(Parameters.PathToFile) Then
		SpreadsheetDocument.Write(Parameters.PathToFile);
		EditProhibited = False;
	EndIf;
	
	Recorded = True;
	Modified = False;
	SetTitle();
	
	ExecuteNotifyProcessing(EndProcessor, True);
	
EndProcedure

&AtClient
Procedure StartSaveFileDialog(Val EndProcessor)
	
	Var SaveFileDialog, NotifyDescription;
	
	SaveFileDialog = New FileDialog(FileDialogMode.Save);
	SaveFileDialog.FullFileName = DocumentName;
	SaveFileDialog.Filter = NStr("en='Spreadsheet document';ru='Табличный документ'") + " (*.mxl)|*.mxl";
	
	NotifyDescription = New NotifyDescription("WhenFileSelectionDialogComplete", ThisObject, EndProcessor);
	SaveFileDialog.Show(NOTifyDescription);
	
EndProcedure

&AtClient
Procedure WhenFileSelectionDialogComplete(SelectedFiles, EndProcessor) Export
	
	If SelectedFiles = Undefined Then
		Return;
	EndIf;
	
	FullFileName = SelectedFiles[0];
	
	Parameters.PathToFile = FullFileName;
	DocumentName = Mid(FullFileName, StrLen(FileDescription(FullFileName).Path) + 1);
	If Lower(Right(DocumentName, 4)) = ".mxl" Then
		DocumentName = Left(DocumentName, StrLen(DocumentName) - 4);
	EndIf;
	
	WriteSpreadsheetDocumentFileNameSelected(EndProcessor);
	
EndProcedure

&AtClient
Function FileDescription(FullName)
	
	SeparatorPosition = StringFunctionsClientServer.FindCharFromEnd(FullName, GetPathSeparator());
	
	Name = Mid(FullName, SeparatorPosition + 1);
	Path = Left(FullName, SeparatorPosition);
	
	ExpansionPosition = StringFunctionsClientServer.FindCharFromEnd(Name, ".");
	
	BaseName = Left(Name, ExpansionPosition - 1);
	Extension = Mid(Name, ExpansionPosition + 1);
	
	Result = New Structure;
	Result.Insert("FullName", FullName);
	Result.Insert("Name", Name);
	Result.Insert("Path", Path);
	Result.Insert("BaseName", BaseName);
	Result.Insert("Extension", Extension);
	
	Return Result;
	
EndFunction
	
&AtClient
Function NewDocumentName()
	Return NStr("en='New';ru='Новый'");
EndFunction

&AtClient
Procedure SetTitle()
	
	Title = DocumentName;
	If IsNew() Then
		Title = Title + " (" + NStr("en='create';ru='создать'") + ")";
	ElsIf EditProhibited Then
		Title = Title + " (" + NStr("en='view only';ru='только просмотр'") + ")";
	EndIf;
	
EndProcedure

&AtClient
Procedure CustomizeCommandsPresentation()
	
	DocumentIsEditing = Items.SpreadsheetDocument.Edit;
	Items.Edit.Check = DocumentIsEditing;
	Items.EditingCommands.Enabled = DocumentIsEditing;
	Items.WriteAndClose.Enabled = DocumentIsEditing Or Modified;
	Items.Write.Enabled = DocumentIsEditing Or Modified;
	
	If DocumentIsEditing AND Not IsBlankString(Parameters.MetadataObjectTemplateName) Then
		Items.Warning.Visible = True;
	EndIf;
	
EndProcedure

&AtClient
Function IsNew()
	Return IsBlankString(Parameters.MetadataObjectTemplateName) AND IsBlankString(Parameters.PathToFile);
EndFunction

&AtClient
Procedure EditInExternalApplicationEnd(ImportedSpreadsheetDocument, AdditionalParameters) Export
	If ImportedSpreadsheetDocument = Undefined Then
		Return;
	EndIf;
	
	Modified = True;
	RefreshSpreadsheetDocument(ImportedSpreadsheetDocument);
EndProcedure

&AtServer
Procedure RefreshSpreadsheetDocument(ImportedSpreadsheetDocument)
	SpreadsheetDocument = ImportedSpreadsheetDocument;
EndProcedure


&AtClient
Procedure SetInitialFormSettings()
	
	If Not IsBlankString(Parameters.PathToFile) AND Not EditProhibited Then
		Items.SpreadsheetDocument.Edit = True;
	EndIf;
	
	SetDocumentName();
	SetTitle();
	CustomizeCommandsPresentation();
	CustomizeTableDocumentRepresentation();
	
EndProcedure

&AtClient
Procedure SetDocumentName()

	If IsBlankString(DocumentName) Then
		UsedNames = New Array;
		Notify("QueryOfEditingSpreadsheetDocumentsNames", UsedNames, ThisObject);
		
		IndexOf = 1;
		While UsedNames.Find(NewDocumentName() + IndexOf) <> Undefined Do
			IndexOf = IndexOf + 1;
		EndDo;
		
		DocumentName = NewDocumentName() + IndexOf;
	EndIf;

EndProcedure

&AtClient
Procedure WhenInitializationFileIsComplete(File, AdditionalParameters) Export
	
	If IsBlankString(DocumentName) Then
		DocumentName = File.BaseName;
	EndIf;
	
	NotifyDescription = New NotifyDescription("WhenOnlyReadingReceivingEnd", ThisObject);
	File.StartReceivingReadOnly(NOTifyDescription);
	
EndProcedure

&AtClient
Procedure WhenOnlyReadingReceivingEnd(ReadOnly, AdditionalParameters) Export
	
	EditProhibited = ReadOnly;
	SetInitialFormSettings();
	
EndProcedure

#EndRegion
